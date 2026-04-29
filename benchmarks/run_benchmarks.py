#!/usr/bin/env python3
import argparse
import os
import subprocess
import re
import json
import csv
import time
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from statistics import mean, stdev

# Configuration
BENCHMARK_DIR = os.path.dirname(os.path.abspath(__file__))
PLOTS_DIR = os.path.join(BENCHMARK_DIR, "plots")
RESULTS_JSON = os.path.join(BENCHMARK_DIR, "benchmark_results.json")
RESULTS_CSV = os.path.join(BENCHMARK_DIR, "benchmark_results.csv")

# Define total valid accesses for checks_per_sec_overhead
# (Calculated based on N and N_REPEATS in the .f90 files)
BENCH_ACCESSES = {
    "bench1_static_sequential": (40000000 + 40000000/64 + 40000000) * 10,
    "bench2_allocatable_descriptor": (20000000 + 20000001 + sum(int(20000000 * (0.9**i)) for i in range(20))) * 10,
    "bench3_assumed_shape_calls": (15000000 + 15000000 + 7500000) * 10
}

# Colors
C_BASE = "#4C72B0"
C_SAN = "#DD8452"
C_SINGLE = "#55A868"

# Ensure plots directory exists
os.makedirs(PLOTS_DIR, exist_ok=True)

# Global settings (will be updated by main)
FLANG = "flang-new"
RUNTIME = "runtime/flang_bounds_check.o"
SDK = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
N_RUNS = 5

def run_command(cmd, env=None):
    """Runs a shell command and returns (stdout, stderr, returncode)."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, env=env)
    return result.stdout, result.stderr, result.returncode

def compile_benchmarks():
    """Compiles each benchmark in baseline and sanitized variants."""
    benchmarks = [f for f in os.listdir(BENCHMARK_DIR) if f.endswith(".f90")]
    binaries = {}

    for b in benchmarks:
        name = b.replace(".f90", "")
        base_bin = os.path.join(BENCHMARK_DIR, f"{name}_base")
        san_bin = os.path.join(BENCHMARK_DIR, f"{name}_san")
        
        # Baseline compilation
        print(f"Compiling baseline: {name}...")
        base_cmd = f"{FLANG} -O2 -isysroot {SDK} {os.path.join(BENCHMARK_DIR, b)} -o {base_bin}"
        out, err, code = run_command(base_cmd)
        if code != 0:
            print(f"Error compiling baseline {name}:\n{err}")
            exit(1)
            
        # Sanitized compilation
        print(f"Compiling sanitized: {name}...")
        san_cmd = f"{FLANG} -O2 -mllvm -bounds-check-hlfir -isysroot {SDK} {os.path.join(BENCHMARK_DIR, b)} {RUNTIME} -o {san_bin}"
        out, err, code = run_command(san_cmd)
        if code != 0:
            print(f"Error compiling sanitized {name}:\n{err}")
            exit(1)
            
        binaries[name] = {"base": base_bin, "san": san_bin}
    
    return binaries

def parse_output(stdout, stderr):
    """Parses benchmark output for phases, checksums, and OOB events."""
    phases = {}
    # Robust regex for explicit E-format output
    # Matches: [PHASE:Name] wall= 1.23E+00 cpu= 4.56E-01 throughput= 7.89E+02
    phase_pattern = re.compile(r"\[PHASE:(?P<name>\w+)\]\s*wall=\s*(?P<wall>[+-]?[\d\.Ede+-]+).*?cpu=\s*(?P<cpu>[+-]?[\d\.Ede+-]+).*?throughput=\s*(?P<tp>[+-]?[\d\.Ede+-]+)", re.IGNORECASE)
    
    found_any = False
    for line in stdout.splitlines():
        match = phase_pattern.search(line)
        if match:
            found_any = True
            p_name = match.group("name")
            try:
                phases[p_name] = {
                    "wall": float(match.group("wall").replace("d", "e").replace("D", "E")),
                    "cpu": float(match.group("cpu").replace("d", "e").replace("D", "E")),
                    "throughput": float(match.group("tp").replace("d", "e").replace("D", "E"))
                }
            except ValueError as e:
                print(f"  Warning: Could not parse values in line: {line} ({e})")
            
    if not found_any and stdout:
        print("  Warning: No phases matched in stdout. First 100 chars of stdout:")
        print(f"  {stdout[:100]}...")
        
    oob_detected = False
    oob_description = ""
    oob_keywords = ["bounds", "out of range", "index", "runtime error", "Bounds Violation"]
    if any(kw.lower() in (stdout + stderr).lower() for kw in oob_keywords):
        oob_detected = True
        oob_description = "Sanitizer detected OOB access"
        
    return phases, oob_detected, oob_description

def execute_benchmarks(binaries):
    """Executes each binary N_RUNS times and collects metrics."""
    results = {}

    for name, bins in binaries.items():
        print(f"Executing benchmark: {name}")
        results[name] = {
            "baseline": {"phases": {}, "total_wall": []},
            "sanitized": {"phases": {}, "total_wall": [], "exit_codes": []},
            "metrics": {}
        }
        
        # Run baseline
        for i in range(N_RUNS):
            stdout, stderr, code = run_command(bins["base"])
            phases, _, _ = parse_output(stdout, stderr)
            run_total_wall = 0
            for p_name, metrics in phases.items():
                if p_name not in results[name]["baseline"]["phases"]:
                    results[name]["baseline"]["phases"][p_name] = {"wall_times": [], "cpu_times": [], "throughput": []}
                results[name]["baseline"]["phases"][p_name]["wall_times"].append(metrics["wall"])
                results[name]["baseline"]["phases"][p_name]["cpu_times"].append(metrics["cpu"])
                results[name]["baseline"]["phases"][p_name]["throughput"].append(metrics["throughput"])
                run_total_wall += metrics["wall"]
            results[name]["baseline"]["total_wall"].append(run_total_wall)
                
        # Run sanitized
        for i in range(N_RUNS):
            stdout, stderr, code = run_command(bins["san"])
            phases, oob, desc = parse_output(stdout, stderr)
            results[name]["sanitized"]["exit_codes"].append(code)
            
            run_total_wall = 0
            for p_name, metrics in phases.items():
                if p_name not in results[name]["sanitized"]["phases"]:
                    results[name]["sanitized"]["phases"][p_name] = {"wall_times": [], "cpu_times": [], "throughput": []}
                results[name]["sanitized"]["phases"][p_name]["wall_times"].append(metrics["wall"])
                results[name]["sanitized"]["phases"][p_name]["cpu_times"].append(metrics["cpu"])
                results[name]["sanitized"]["phases"][p_name]["throughput"].append(metrics["throughput"])
                run_total_wall += metrics["wall"]
            results[name]["sanitized"]["total_wall"].append(run_total_wall)

        # Compute summary metrics per benchmark
        b_wall = results[name]["baseline"]["total_wall"]
        s_wall = results[name]["sanitized"]["total_wall"]
        
        mean_base = mean(b_wall)
        std_base = stdev(b_wall) if len(b_wall) > 1 else 0.0
        mean_san = mean(s_wall)
        std_san = stdev(s_wall) if len(s_wall) > 1 else 0.0
        
        results[name]["metrics"]["baseline_mean_s"] = mean_base
        results[name]["metrics"]["baseline_stddev_s"] = std_base
        results[name]["metrics"]["sanitized_mean_s"] = mean_san
        results[name]["metrics"]["sanitized_stddev_s"] = std_san
        
        overhead_pct = ((mean_san - mean_base) / mean_base * 100) if mean_base > 0 else 0.0
        slowdown_ratio = (mean_san / mean_base) if mean_base > 0 else 1.0
        oob_detected = all(c != 0 for c in results[name]["sanitized"]["exit_codes"])
        
        total_accesses = BENCH_ACCESSES.get(name, 0)
        time_diff = mean_san - mean_base
        checks_per_sec = (total_accesses / time_diff) if time_diff > 0 else 0.0
        
        results[name]["metrics"]["overhead_pct"] = overhead_pct
        results[name]["metrics"]["slowdown_ratio"] = slowdown_ratio
        results[name]["metrics"]["oob_detected"] = oob_detected
        results[name]["metrics"]["checks_per_sec_overhead"] = checks_per_sec

        # Compute per-phase overhead for compatibility
        results[name]["overhead_per_phase"] = {}
        for p_name in results[name]["baseline"]["phases"]:
            base_p_wall = results[name]["baseline"]["phases"][p_name]["wall_times"]
            mean_p_base = mean(base_p_wall)
            results[name]["baseline"]["phases"][p_name]["mean_wall"] = mean_p_base
            results[name]["baseline"]["phases"][p_name]["mean_tp"] = mean(results[name]["baseline"]["phases"][p_name]["throughput"])
            
            if p_name in results[name]["sanitized"]["phases"]:
                san_p_wall = results[name]["sanitized"]["phases"][p_name]["wall_times"]
                mean_p_san = mean(san_p_wall)
                results[name]["sanitized"]["phases"][p_name]["mean_wall"] = mean_p_san
                results[name]["sanitized"]["phases"][p_name]["mean_tp"] = mean(results[name]["sanitized"]["phases"][p_name]["throughput"])
                results[name]["overhead_per_phase"][p_name] = (mean_p_san / mean_p_base) if mean_p_base > 0 else 1.0

    return results

def print_header():
    header = """
    ================================================================================
    |                                                                              |
    |             FLANG HLFIR ARRAY BOUNDS SANITIZER BENCHMARK SUITE               |
    |                                                                              |
    |       Evaluating Performance Overhead and Detection Correctness              |
    |                                                                              |
    ================================================================================
    """
    print(header)

def generate_visualizations(results):
    """Generates 4 plots per benchmark, visualizing metrics across phases A, B, and C."""
    sns.set_theme(style="whitegrid")
    
    for b_name, b_data in results.items():
        b_short = b_name.split("_")[0]
        phases = sorted(b_data["baseline"]["phases"].keys())
        
        # Plot 1 — <bench>_mean_time.png
        plt.figure(figsize=(10, 6))
        base_means = [b_data["baseline"]["phases"][p]["mean_wall"] for p in phases]
        san_means = [b_data["sanitized"]["phases"][p]["mean_wall"] for p in phases]
        
        x = np.arange(len(phases))
        width = 0.35
        
        plt.bar(x - width/2, base_means, width, label='Baseline', color=C_BASE)
        plt.bar(x + width/2, san_means, width, label='Sanitized', color=C_SAN)
        
        plt.ylabel('Wall-clock Time (s)')
        plt.title(f'{b_short}: Mean Execution Time by Phase')
        plt.xticks(x, phases)
        plt.legend()
        plt.savefig(os.path.join(PLOTS_DIR, f"{b_short}_mean_time.png"), dpi=150)
        plt.close()

        # Plot 2 — <bench>_overhead_pct.png
        plt.figure(figsize=(10, 6))
        overheads = [((b_data["sanitized"]["phases"][p]["mean_wall"] - b_data["baseline"]["phases"][p]["mean_wall"]) / 
                      max(b_data["baseline"]["phases"][p]["mean_wall"], 1e-9) * 100) for p in phases]
        bars = plt.barh(phases, overheads, color=C_SINGLE)
        plt.axvline(0, color='red', linestyle='--')
        plt.xlabel('Overhead (%)')
        plt.title(f'{b_short}: Sanitizer Overhead (%) by Phase')
        for i, bar in enumerate(bars):
            plt.text(bar.get_width(), bar.get_y() + bar.get_height()/2, f' {overheads[i]:.1f}%', va='center')
        plt.savefig(os.path.join(PLOTS_DIR, f"{b_short}_overhead_pct.png"), dpi=150)
        plt.close()

        # Plot 3 — <bench>_slowdown_ratio.png
        plt.figure(figsize=(10, 6))
        ratios = [b_data["overhead_per_phase"].get(p, 1.0) for p in phases]
        bars = plt.bar(phases, ratios, color=C_SINGLE)
        plt.axhline(1.0, color='grey', linestyle='--', label='No overhead')
        plt.ylabel('Slowdown Ratio')
        plt.title(f'{b_short}: Slowdown Ratio by Phase')
        for i, bar in enumerate(bars):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height(), f'{ratios[i]:.2f}x', ha='center', va='bottom')
        plt.legend()
        plt.savefig(os.path.join(PLOTS_DIR, f"{b_short}_slowdown_ratio.png"), dpi=150)
        plt.close()

        # Plot 4 — <bench>_throughput.png
        plt.figure(figsize=(10, 6))
        base_tps = [b_data["baseline"]["phases"][p]["mean_tp"] for p in phases]
        san_tps = [b_data["sanitized"]["phases"][p]["mean_tp"] for p in phases]
        
        plt.bar(x - width/2, base_tps, width, label='Baseline', color=C_BASE)
        plt.bar(x + width/2, san_tps, width, label='Sanitized', color=C_SAN)
        
        plt.ylabel('Throughput (Gelem/s)')
        plt.title(f'{b_short}: Throughput by Phase')
        plt.xticks(x, phases)
        plt.legend()
        plt.savefig(os.path.join(PLOTS_DIR, f"{b_short}_throughput.png"), dpi=150)
        plt.close()

def save_results(results):
    """Saves results to JSON and CSV."""
    with open(RESULTS_JSON, "w") as f:
        json.dump(results, f, indent=2)
        
    with open(RESULTS_CSV, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "benchmark", "baseline_mean_s", "baseline_stddev_s", 
            "sanitized_mean_s", "sanitized_stddev_s", "overhead_pct", 
            "slowdown_ratio", "oob_detected", "checks_per_sec_overhead"
        ])
        for b_name, b_data in results.items():
            m = b_data["metrics"]
            writer.writerow([
                b_name, 
                m["baseline_mean_s"], m["baseline_stddev_s"],
                m["sanitized_mean_s"], m["sanitized_stddev_s"],
                m["overhead_pct"], m["slowdown_ratio"],
                m["oob_detected"], m["checks_per_sec_overhead"]
            ])

def print_summary(results):
    """Prints a formatted summary table to stdout."""
    print("\n" + "="*100)
    print(f"{'Benchmark':<30} | {'Base (s)':<10} | {'San (s)':<10} | {'Overhead':<10} | {'Slowdown':<10} | {'OOB':<5}")
    print("-" * 100)
    for b_name in sorted(results.keys()):
        m = results[b_name]["metrics"]
        oob_str = "YES" if m["oob_detected"] else "NO"
        print(f"{b_name:<30} | {m['baseline_mean_s']:<10.3f} | {m['sanitized_mean_s']:<10.3f} | {m['overhead_pct']:>8.1f}% | {m['slowdown_ratio']:>8.2f}x | {oob_str:<5}")
    print("="*100 + "\n")

def main():
    global FLANG, RUNTIME, SDK, N_RUNS
    
    parser = argparse.ArgumentParser(description="Flang Array Bounds Sanitizer Benchmarking Suite")
    parser.add_argument("--flang", help="Path to flang compiler binary")
    parser.add_argument("--repeats", type=int, default=5, help="Number of repetitions per benchmark (default: 5)")
    args = parser.parse_args()

    # Priority: CLI argument > Environment variable > Default
    FLANG = args.flang or os.environ.get("FLANG_PATH") or os.environ.get("FLANG") or "flang-new"
    RUNTIME = os.environ.get("RUNTIME") or "runtime/flang_bounds_check.o"
    SDK = os.environ.get("SDK") or "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    N_RUNS = args.repeats

    print_header()
    print(f"Starting Flang Array Bounds Sanitizer Benchmarking Suite...")
    print(f"Compiler: {FLANG}")
    print(f"Repeats: {N_RUNS}")
    binaries = compile_benchmarks()
    results = execute_benchmarks(binaries)
    save_results(results)
    
    try:
        generate_visualizations(results)
        print("Visualizations generated successfully.")
    except ImportError as e:
        print(f"Skipping visualizations: missing dependencies ({e})")
    except Exception as e:
        print(f"Error generating visualizations: {e}")
        
    print_summary(results)
    print(f"Full results saved to {RESULTS_JSON} and {RESULTS_CSV}")

if __name__ == "__main__":
    main()

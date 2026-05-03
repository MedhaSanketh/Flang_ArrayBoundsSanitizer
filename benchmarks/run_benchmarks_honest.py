#!/usr/bin/env python3
import os, subprocess, re, csv, time, argparse

BENCHMARK_DIR = os.path.dirname(os.path.abspath(__file__))

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.stdout, r.stderr, r.returncode

def parse_phases(stdout):
    phases = {}
    pattern = re.compile(
        r"\[PHASE:(\w+)\].*?wall=\s*([\d\.Ee+-]+).*?throughput=\s*([\d\.Ee+-]+)",
        re.IGNORECASE)
    for line in stdout.splitlines():
        m = pattern.search(line)
        if m:
            phases[m.group(1)] = {
                "wall": float(m.group(2).replace('d','e').replace('D','E')),
                "throughput": float(m.group(3).replace('d','e').replace('D','E'))
            }
    return phases

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--flang", default=os.environ.get("FLANG", "flang"))
    parser.add_argument("--runtime", default=os.environ.get("RUNTIME",
        os.path.join(os.path.dirname(BENCHMARK_DIR), "runtime/flang_bounds_check.o")))
    parser.add_argument("--repeats", type=int, default=3)
    args = parser.parse_args()

    benchmarks = [f for f in os.listdir(BENCHMARK_DIR) if f.endswith(".f90")]
    benchmarks.sort()

    # Compile runtime
    runtime_c = os.path.join(os.path.dirname(BENCHMARK_DIR),
                             "runtime/flang_bounds_check.c")
    run(f"clang -c {runtime_c} -o {args.runtime}")

    results = []

    for b in benchmarks:
        name = b.replace(".f90", "")
        src = os.path.join(BENCHMARK_DIR, b)
        base_bin = os.path.join(BENCHMARK_DIR, f"{name}_base")
        san_bin  = os.path.join(BENCHMARK_DIR, f"{name}_san")

        print(f"\n=== {name} ===")

        # Compile
        _, err, code = run(f"{args.flang} -O2 {src} -o {base_bin}")
        if code != 0:
            print(f"COMPILE ERROR (baseline): {err}"); continue

        _, err, code = run(
            f"{args.flang} -fcheck=bounds {src} {args.runtime} -o {san_bin}")
        if code != 0:
            print(f"COMPILE ERROR (sanitized): {err}"); continue

        # Run baseline N times
        base_walls = []
        for i in range(args.repeats):
            stdout, _, _ = run(base_bin)
            phases = parse_phases(stdout)
            total = sum(p["wall"] for p in phases.values())
            base_walls.append(total)
            print(f"  baseline run {i+1}: {total:.3f}s  phases={list(phases.keys())}")

        # Run sanitized N times (may abort on OOB — capture stderr)
        san_walls = []
        oob_detected = False
        for i in range(args.repeats):
            stdout, stderr, code = run(san_bin)
            if "Bounds Violation" in stderr:
                oob_detected = True
            phases = parse_phases(stdout)
            total = sum(p["wall"] for p in phases.values())
            san_walls.append(total)
            print(f"  sanitized run {i+1}: {total:.3f}s  oob={oob_detected}")

        if not base_walls or not san_walls:
            print("  No timing data collected, skipping")
            continue

        mean_base = sum(base_walls) / len(base_walls)
        mean_san  = sum(san_walls)  / len(san_walls)
        overhead  = (mean_san - mean_base) / mean_base * 100
        slowdown  = mean_san / mean_base

        print(f"  baseline: {mean_base:.3f}s")
        print(f"  sanitized: {mean_san:.3f}s")
        print(f"  overhead: {overhead:.1f}%  slowdown: {slowdown:.2f}x")
        print(f"  OOB detected: {oob_detected}")

        results.append({
            "benchmark": name,
            "baseline_mean_s": round(mean_base, 4),
            "sanitized_mean_s": round(mean_san, 4),
            "overhead_pct": round(overhead, 2),
            "slowdown_ratio": round(slowdown, 3),
            "oob_detected": oob_detected
        })

    # Save CSV
    csv_path = os.path.join(BENCHMARK_DIR, "benchmark_results_honest.csv")
    with open(csv_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)

    print(f"\nResults saved to {csv_path}")
    print("\n" + "="*70)
    print(f"{'Benchmark':<35} {'Base':>8} {'San':>8} {'Overhead':>10} {'OOB':>5}")
    print("-"*70)
    for r in results:
        print(f"{r['benchmark']:<35} {r['baseline_mean_s']:>8.3f} "
              f"{r['sanitized_mean_s']:>8.3f} {r['overhead_pct']:>9.1f}% "
              f"{'YES' if r['oob_detected'] else 'NO':>5}")
    print("="*70)

if __name__ == "__main__":
    main()

# Flang Array Bounds Sanitizer Benchmarking Suite

This suite provides a comprehensive set of benchmarks to evaluate the performance impact and correctness of the Flang/HLFIR-aware array bounds sanitizer.

## Benchmarks Overview

### 1. `bench1_static_sequential.f90`

- **Purpose**: Evaluates overhead for static arrays with compile-time known bounds.
- **Stress Points**: Sequential vs. strided memory access.

### 2. `bench2_allocatable_descriptor.f90`

- **Purpose**: Measures overhead of descriptor-based bounds resolution for allocatable arrays.
- **Stress Points**: Non-default lower bounds and reallocation cycles.

### 3. `bench3_assumed_shape_calls.f90`

- **Purpose**: Analyzes overhead in subroutine calls using assumed-shape dummy arguments.
- **Stress Points**: Call-site overhead and slice forwarding.

## How to Run

Ensure you have the Flang compiler and the sanitizer runtime library built.

```bash
# Basic run with defaults (saves plots to benchmarks/plots/)
source .env
python3 benchmarks/run_benchmarks.py

# Specify flang path and number of repetitions
python3 benchmarks/run_benchmarks.py --flang $FLANG --repeats 5
```

### Generated Artifacts

- **`benchmarks/plots/`**: Directory containing 4 specialized metric plots for each benchmark program:
  - `{bench}_mean_time.png`: Comparison of baseline vs. sanitized wall-clock time per phase.
  - `{bench}_overhead_pct.png`: Percentage increase in execution time introduced by the sanitizer.
  - `{bench}_slowdown_ratio.png`: Performance multiplier for sanitized code compared to baseline.
  - `{bench}_throughput.png`: Comparison of elements processed per second across different phases.
- **`benchmarks/benchmark_results.json`**: Raw timing data, metadata, and calculated metrics in JSON format.
- **`benchmarks/benchmark_results.csv`**: Tabular summary of results per benchmark for easy spreadsheet import.

### Environment Variables

The script respects the following environment variables if not overridden by CLI flags:

- `FLANG_PATH`: Path to the flang binary.
- `RUNTIME`: Path to the `flang_bounds_check.o` runtime library.
- `SDK`: Path to the macOS SDK (required on macOS).

## Interpreting Plots

Each benchmark program (e.g., `bench1`, `bench2`) generates its own set of 4 plots to provide a granular view of performance:

1. **Mean Execution Time**: Shows the average time (in seconds) taken for each internal phase (A, B, C). It includes error bars representing the standard deviation across the 5 runs.
2. **Sanitizer Overhead (%)**: Visualizes the relative slowdown for each phase. A value of 0% indicates no overhead, while values > 100% indicate significant performance impact.
3. **Slowdown Ratio**: Provides a multiplicative view of overhead. A dashed horizontal line at 1.0x represents the "no overhead" baseline.
4. **Throughput (Gelem/s)**: Measures how many "Giga-elements" (billions of array elements) are processed per second. This is useful for understanding the computational density of each phase.

## Interpreting OOB Detection Results

The OOB (Out-Of-Bounds) status is reported in the final summary table printed to the console:

- **YES**: The sanitized program successfully detected the intentional violation and terminated with a non-zero exit code in all runs.
- **NO**: The program either completed successfully or crashed without a proper diagnostic, indicating that the specific OOB scenario is not yet covered by the instrumentation.

## Limitations

- These benchmarks focus on **execution time** overhead, not memory overhead.
- They assume **serial execution**; thread-safety and overhead in parallel regions are not yet measured.
- The OOB sentinels test **basic detection** but do not cover all possible edge cases.

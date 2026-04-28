#!/bin/bash
# Usage: ./run_benchmarks.sh /path/to/flang /path/to/flang_bounds_check.o

FLANG_ARG=$1
RUNTIME_ARG=$2

# Get absolute paths for flang and runtime if they are provided
if [[ -n "$FLANG_ARG" ]]; then
    if [[ "$FLANG_ARG" != /* ]]; then
        FLANG_ARG="$(pwd)/$FLANG_ARG"
    fi
fi
if [[ -n "$RUNTIME_ARG" ]]; then
    if [[ "$RUNTIME_ARG" != /* ]]; then
        RUNTIME_ARG="$(pwd)/$RUNTIME_ARG"
    fi
fi

FLANG=${FLANG_ARG:-/Users/divyabelumana/llvm-project/build/bin/flang}
RUNTIME=${RUNTIME_ARG:-/Users/divyabelumana/Desktop/Flang_ArrayBoundsSanitizer/runtime/flang_bounds_check.o}
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

echo "===================================================="
echo "      HLFIR Bounds Sanitizer Benchmark Runner"
echo "===================================================="
echo "Using flang:   $FLANG"
echo "Using runtime: $RUNTIME"
echo "Using SDK:     $SDK_PATH"
echo "----------------------------------------------------"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

for f in bench_pgms/*.f90; do
    name=$(basename $f .f90)
    echo "Running benchmark: $name"
    
    # 1. Compile WITHOUT bounds checking (Baseline)
    echo "  [1/2] Compiling Baseline..."
    compile_baseline=$($FLANG -O2 -isysroot $SDK_PATH $f -o /tmp/bench_baseline 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Baseline compilation failed for $name"
        echo "$compile_baseline"
        continue
    fi
    
    # 2. Compile WITH bounds checking (Sanitized)
    echo "  [2/2] Compiling with HLFIR Bounds Sanitizer..."
    compile_sanitized=$($FLANG -O2 -mllvm -bounds-check-hlfir -isysroot $SDK_PATH $f $RUNTIME -o /tmp/bench_sanitized 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Sanitized compilation failed for $name"
        echo "$compile_sanitized"
        continue
    fi
    
    # 3. Run and measure Baseline
    echo "  Executing Baseline..."
    start_time=$(python3 -c 'import time; print(time.time())')
    /tmp/bench_baseline > /dev/null
    end_time=$(python3 -c 'import time; print(time.time())')
    baseline_dur=$(python3 -c "print($end_time - $start_time)")
    
    # 4. Run and measure Sanitized
    echo "  Executing Sanitized..."
    start_time=$(python3 -c 'import time; print(time.time())')
    /tmp/bench_sanitized > /dev/null
    end_time=$(python3 -c 'import time; print(time.time())')
    sanitized_dur=$(python3 -c "print($end_time - $start_time)")
    
    # 5. Report results
    overhead=$(python3 -c "print((($sanitized_dur / $baseline_dur) - 1) * 100)")
    echo "  Results for $name:"
    printf "    Baseline:  %.4f seconds\n" $baseline_dur
    printf "    Sanitized: %.4f seconds\n" $sanitized_dur
    printf "    Overhead:  %.2f%%\n" $overhead
    echo "----------------------------------------------------"
done

echo "Benchmarks complete."

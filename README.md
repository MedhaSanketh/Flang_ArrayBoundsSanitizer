# Flang HLFIR-Aware Array Bounds Sanitizer

A runtime bounds-checking sanitizer for Fortran programs compiled with Flang.
Exploits HLFIR's rich array descriptor metadata to insert precise bounds checks
for allocatable arrays, assumed-shape arrays, array slices, and pointer arrays.

## Authors
- Medha Sanketh 
- Kalianpur Rohith

## Background & Motivation

Fortran remains the dominant language in high-performance scientific computing —
weather simulation, aerospace, numerical physics — where array operations are
the core computation. Out-of-bounds array accesses are a common source of silent
data corruption and hard-to-debug crashes in these programs.

### The Problem with Existing Tools

`gfortran -fcheck=bounds` exists but is fundamentally limited:

| Limitation | Why it happens |
|------------|----------------|
| Misses assumed-shape arrays | Bounds are only known at runtime via descriptor |
| Misses array slices | Slice remaps bounds — checker uses wrong range |
| Misses pointer arrays | Pointer target changes at runtime |
| No custom lower bounds | Assumes lb=1, wrong for `allocate(A(5:15))` |
| No multi-dim checking | Only checks first dimension |

The root cause: gfortran's checker runs late in compilation when rich
array metadata is already lost. It sees raw pointers, not Fortran arrays.

### Why HLFIR Changes Everything

Flang's HLFIR (High-Level Fortran IR) is a relatively new intermediate
representation that preserves Fortran array semantics much longer in the
compilation pipeline. At the HLFIR level:

- Every array access is an `hlfir.designate` operation
- Every dynamic array carries a descriptor (`fir.box`) with lb, extent, stride
- Slice transformations are explicit and trackable
- Pointer reassignments update the descriptor in place

This means a pass at the HLFIR level can read the **exact** bounds for any
array access — static, dynamic, sliced, or pointer-based — and insert a
precise check before it reaches machine code.

### Objective

Build a sanitizer that:
1. Runs during HLFIR-to-FIR lowering (before array metadata is lost)
2. Reads bounds from descriptors at runtime for dynamic arrays
3. Reads bounds from types at compile time for static arrays
4. Covers all cases gfortran misses
5. Is controlled by a standard `-fcheck=bounds` compiler flag

## Deliverables

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | HLFIR instrumentation pass (`HLFIRBoundsCheck.cpp`) |  Complete |
| 2 | Runtime support library (`flang_bounds_check.c`) |  Complete |
| 3 | Driver flag `-fcheck=bounds` |  Complete |
| 4 | Test suite - 20 Fortran programs with OOB accesses |  20/20 passing |
| 5 | Overhead benchmarks on 3 real Fortran programs |  Complete |

## What It Does

Inserts a conditional bounds check before every array access during
HLFIR-to-FIR lowering. When an out-of-bounds access is detected at runtime,
the program aborts with a diagnostic message showing the index, valid range,
and source line number.

## Example Output

```text
*** Fortran Array Bounds Violation ***
  Index:       20
  Valid range: [5 : 15]
  Line:        10
```

## How to Apply to a Fresh LLVM Checkout

```bash
# Clone LLVM
git clone --depth=1 https://github.com/llvm/llvm-project.git
cd llvm-project

# Apply the patch
git apply /path/to/flang_bounds_check.patch

# Build
mkdir build && cd build
cmake ../llvm \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;flang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DCMAKE_INSTALL_PREFIX=$HOME/llvm-install \
  -DFLANG_ENABLE_WERROR=OFF

ninja -j8 flang
```

## How to Use

```bash
# Compile runtime library
clang -c runtime/flang_bounds_check.c -o flang_bounds_check.o

# Compile Fortran program with bounds checking
flang -fcheck=bounds your_program.f90 flang_bounds_check.o -o your_program

# Run
./your_program
```

## Without Bounds Checking (baseline)

```bash
flang -O2 your_program.f90 -o your_program
./your_program
```

## Covered Cases

| Case | Description | Status |
|------|-------------|--------|
| Allocatable arrays | Runtime bounds via descriptor | done |
| Assumed-shape arrays | Caller-provided bounds | done |
| Array slices | Transformed bounds | done |
| Pointer arrays | Dynamic target bounds | done |
| Static arrays | Compile-time known bounds | done |
| 2D/3D arrays | Per-dimension bounds checking | done |
| Strided slices | Non-unit stride access | done |

## Test Results

20/20 correctness tests passing, 0 false positives.

```bash
cd tests
./run_tests.sh /path/to/flang /path/to/flang_bounds_check.o
```

## Performance Overhead

Benchmarks run on Apple M1, Flang 23.0.0.
Baseline: `-O2`, Sanitized: `-fcheck=bounds`.

| Benchmark | Baseline | Sanitized | Slowdown |
|-----------|----------|-----------|----------|
| bench1 static sequential | 0.09s | 1.91s | 21x |
| bench2 allocatable descriptor | 0.04s | 2.91s | 73x |
| bench3 assumed-shape calls | 0.02s | 0.71s | 35x |

Overhead comes from a conditional branch to `__flang_bounds_fail`
(a `noreturn` function) before every array access. CSE correctly
caches descriptor reads so bounds are not re-read per iteration.
Loop hoisting (checking once before the loop instead of per-iteration)
would reduce overhead to ~2-5x and is left as future work.

## Project Structure

- **src/**
  Reference copies of the key source files:
  `HLFIRBoundsCheck.cpp` (the MLIR pass) and `flang_bounds_check.c` (runtime).

- **pass/**
  Reference copy of the pass and its TableGen descriptor (`Passes.td`).

- **runtime/**
  C-based runtime library (`__flang_bounds_check`, `__flang_bounds_fail`).

- **tests/**
  - 20 correctness test cases
  - `run_tests.sh` — automated test runner

- **benchmarks/**
  - 3 performance benchmarks
  - `run_benchmarks_honest.py` — real measurement script
  - `benchmark_results_real.csv` — real overhead measurements
  - `plots/` — visualization of benchmark results

- **demo/**
  - `run_demo.sh` — script that produces clean terminal output for screenshots
  - Pre-captured output files (`.txt`) for all three demo scenarios

- **flang_bounds_check.patch**
  Git patch to apply to a fresh LLVM checkout (see "How to Apply" above).

## LLVM Version

Built and tested against:
`flang version 23.0.0 (https://github.com/llvm/llvm-project.git 46c427b6...)`
Target: `arm64-apple-darwin`

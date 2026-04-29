# Flang HLFIR-Aware Array Bounds Sanitizer

A runtime bounds-checking sanitizer for Fortran programs compiled with Flang.
Exploits HLFIR's rich array descriptor metadata to insert precise bounds checks
for allocatable arrays, assumed-shape arrays, array slices, and pointer arrays.

## What It Does

Inserts calls to `__flang_bounds_check()` before every descriptor-based array
access in Fortran programs. The runtime function checks if the index is within
bounds and aborts with a diagnostic if not.

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
./build/bin/flang -O0 \
  -mllvm -bounds-check-hlfir \
  your_program.f90 \
  flang_bounds_check.o \
  -o your_program

# Run
./your_program
```

## Without Bounds Checking (baseline)

```bash
./build/bin/flang -O2 your_program.f90 -o your_program
./your_program
```

## Covered Cases

| Case                 | Description                   |
| -------------------- | ----------------------------- |
| Allocatable arrays   | Runtime bounds via descriptor |
| Assumed-shape arrays | Caller-provided bounds        |
| Array slices         | Transformed bounds            |
| Pointer arrays       | Dynamic target bounds         |
| 2D/3D arrays         | Multi-dimensional             |
| Stride case          | Non-unit array access         |

## Project Structure

- **pass/**
  Contains the HLFIR instrumentation pass implementation.

- **runtime/**
  C-based runtime library used for bounds checking support.

- **tests/**
  Includes:
  - 20 correctness test cases

- **benchmarks/**
  - 3 performance benchmarks
  - run_benchmarks.py: Script to run benchmarks
  - benchmarks.json: Benchmark results in JSON format
  - benchmarks.csv: Benchmark results in CSV format
  - benchmarks.png: Benchmark results plot

- **flang_bounds_check.patch**
  Patch file to be applied to the LLVM/Flang source tree.

## LLVM Version

Built and tested against:
`flang version 23.0.0 (https://github.com/llvm/llvm-project.git 46c427b6...)`
Target: `arm64-apple-darwin`

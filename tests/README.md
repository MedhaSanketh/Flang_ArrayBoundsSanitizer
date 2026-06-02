# Flang Array Bounds Checking Sanitizer — Test Suite

## Overview

This suite contains **20 correctness tests** for validating a compiler-based
array bounds checking sanitizer in Flang (HLFIR-aware). Benchmarks are in `benchmarks/`.

Focus areas:

Allocatable arrays (runtime bounds)
Assumed-shape arrays (caller-provided bounds)
Array slices (transformed bounds)
Pointer-based arrays (dynamic targets)

---

## Directory Layout

```
tests/
├── README.md
├── run_tests.sh
│
├── test_pgms/
├── -- STATIC ARRAYS --
├── test_static_valid.f90          [01] Static array, all accesses valid
├── test_static_oob_upper.f90      [02] Static array, index > upper bound
├── test_static_oob_lower.f90      [03] Static array, index < lower bound (0)
│
├── -- ALLOCATABLE ARRAYS --
├── test_allocatable_valid.f90     [04] Allocatable A(5:15), valid accesses
├── test_allocatable_oob.f90       [05] Allocatable A(5:15), index < lower bound 5
│
├── -- ASSUMED-SHAPE ARRAYS --
├── test_assumed_shape_valid.f90   [06] Assumed-shape subroutine, valid accesses
├── test_assumed_shape_oob.f90     [07] Assumed-shape subroutine, index beyond size
│
├── -- ARRAY SLICES --
├── test_slice_valid.f90           [08] Slices A(3:8) and A(1:9:2) passed, valid
├── test_slice_complex.f90         [09] Slice A(2:5) passed; index 5 > slice size
│
├── -- POINTER-BASED ARRAYS --
├── test_pointer_valid.f90         [10] Pointer => full array, valid accesses
├── test_pointer_oob.f90           [11] Pointer => A(3:7), access index 8
├── test_pointer_reassign.f90      [12] Pointer reassigned BIG->SMALL, stale index
│
├── -- MULTI-DIMENSIONAL ARRAYS --
├── test_2d_valid.f90              [13] 2D array A(4,6), all valid
├── test_2d_oob_dim1.f90           [14] 2D array, row index exceeds bound
├── test_3d_oob_dim3.f90           [15] 3D array, depth index exceeds bound
│
├── -- STRIDES --
├── test_stride_valid.f90          [16] Stride array A(1:10:2), valid accesses
├── test_stride_oob.f90            [17] Stride array A(1:10:2), index > upper bound
│
├── -- EDGE CASES & COMPLEX SCENARIOS --
├── test_loop_assumed.f90          [18] Loop iterates over assumed shape array A(1:10:2)
├── test_nested_calls.f90          [19] Nested subroutines with slice threading
├── test_dynamic_bounds.f90        [20] Runtime-determined N, accesses index N+1
│
```

---

## How to Compile & Run

### **Run All Tests**

```bash
# From the repo root
clang -c runtime/flang_bounds_check.c -o /tmp/flang_bounds_check.o
cd tests
./run_tests.sh ~/llvm-project/build/bin/flang /tmp/flang_bounds_check.o
```

Or use the top-level script:

```bash
./run.sh
```

### **Run Individual Program**

```bash
FLANG=~/llvm-project/build/bin/flang
RUNTIME=/tmp/flang_bounds_check.o

$FLANG -O0 -fcheck=bounds tests/test_pgms/<NAME>.f90 $RUNTIME -o /tmp/bin
/tmp/bin
```

---

## Expected Outcomes

- Programs named `*_valid.*` or containing "valid" in name: **exit 0**, no error.
- Programs named `*_oob.*` or `bench_*`: **abort/trap** at the line marked `! EXPECTED: OOB ERROR`.
- The sanitizer should report the **exact array name, index value, and bounds** in its diagnostic output.

---

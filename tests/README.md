# Flang Array Bounds Checking Sanitizer — Test Suite

## Overview

This suite contains **20 correctness tests** and **3 benchmarks** for validating a compiler-based array bounds checking sanitizer in Flang (HLFIR-aware).

Focus areas:

Allocatable arrays (runtime bounds)
Assumed-shape arrays (caller-provided bounds)
Array slices (transformed bounds)
Pointer-based arrays (dynamic targets)

---

## Directory Layout

```
fortran_test_suite/
├── README.md
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
├── -- EDGE CASES & COMPLEX SCENARIOS --
├── test_loop_oob.f90              [16] Loop iterates N+1 times on N-element array
├── test_nested_calls.f90          [17] Nested subroutines with slice threading
├── test_mixed_alloc_slice_ptr.f90 [18] Allocatable + slice + pointer chain, OOB
├── test_zero_length.f90           [19] Zero-length array, any access is OOB
├── test_dynamic_bounds.f90        [20] Runtime-determined N, accesses index N+1
│
├── bench_pgms/
└── -- BENCHMARKS --
    bench_large_static.f90         [B1] 100K static array: 100K valid reads, 1 OOB
    bench_large_2d_alloc.f90       [B2] 1000x1000 allocatable: 1M valid, 1 OOB
    bench_assumed_shape_stress.f90 [B3] 50K elem, 3-layer subroutine chain, OOB at leaf
```

---

## How to Compile

```bash
# With bounds checking enabled (Flang + sanitizer flag)
flang-new -fbounds-check -o <binary> <file>.f90

# Or using your custom sanitizer build:
flang-new -fsanitize=array-bounds -O0 -o <binary> <file>.f90

# Without sanitizer (baseline / reference)
flang-new -O2 -o <binary> <file>.f90
```

---

## How to Run

./<binary>
echo $?

---

## Expected Outcomes

- Programs named `*_valid.*` or containing "valid" in name: **exit 0**, no error.
- Programs named `*_oob.*` or `bench_*`: **abort/trap** at the line marked `! EXPECTED: OOB ERROR`.
- The sanitizer should report the **exact array name, index value, and bounds** in its diagnostic output.

---

# Design Document: Flang HLFIR-Aware Array Bounds Sanitizer

## Problem Statement

Fortran array out-of-bounds (OOB) accesses compile silently under `-O2`.
Existing tools miss critical cases:

| Tool | Misses |
|------|--------|
| `gfortran -fbounds-check` | Slice-relative bounds, custom lb, pointer retargets |
| AddressSanitizer | Fortran array semantics entirely |
| Valgrind | Semantic violations (sees raw memory, not arrays) |

## Why HLFIR?

Flang's HLFIR (High-Level Fortran IR) preserves array metadata that is
lost at lower IR levels:

- Every array access → `hlfir.designate` operation
- Every dynamic array → `fir.box` descriptor with lb, extent, stride
- Slice transformations → explicit, trackable
- Pointer reassignments → descriptor updated in place

Once lowering reaches FIR/LLVM IR, descriptors dissolve into raw pointer
arithmetic. **HLFIR is the only level where precise bounds checking is possible.**

## Approach

An MLIR `OperationPass<ModuleOp>` walks every `hlfir::DesignateOp` and
inserts a `fir.if` conditional calling `__flang_bounds_fail` (noreturn)
before each array element access.

### Two Code Paths

**Path A — Descriptor-based (allocatable, assumed-shape, pointer):**
fir.box_dims(box, dim) → (lb, extent, stride)
ub = lb + extent - 1
if (index < lb OR index > ub) → call __flang_bounds_fail

**Path B — Static arrays:**
Read shape from FIR SequenceType at compile time
lb = 1 (always for static), ub = shape[dim]
if (index < lb OR index > ub) → call __flang_bounds_fail

### Why `noreturn`?

`__flang_bounds_fail` is marked `noreturn` in C and with `llvm.noreturn`
in IR. This prevents LLVM's optimizer from treating the `fir.if` block as
dead code even when bounds are provably safe — ensuring checks survive
the optimization pipeline.

## Alternatives Considered

### Source-level Transform
Rejected: requires a full Fortran parser, misses compiler-generated
accesses, couples to syntax variants.

### Post-FIR Instrumentation
Rejected: descriptors are dissolved into raw pointer arithmetic at FIR
level. Custom lb, slice offsets, and pointer retargets become implicit —
unrecoverable without reanalysis.

### Unconditional External Call (first attempt)
Tried: replaced `fir.if` with an unconditional call to
`__flang_bounds_check()` (which does the comparison in C). Worked but
paid call overhead on every access — 21-73x slowdown. Reverted to
`fir.if` + `noreturn` fail function.

## Driver Flag Design

`-fcheck=bounds` is wired through 5 files following Flang's standard
flag registration pattern (see IMPLEMENTATION.md for details).

## Known Limitations

- **Overhead**: 21x on tight loops due to per-access branch cost.
  Fix: loop hoisting (future work, requires value range analysis).
- **Coarrays**: not supported.
- **Allocatable components of derived types**: not supported.

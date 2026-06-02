# Implementation Details : Flang HLFIR-Aware Array Bounds Sanitizer

## Files Modified in LLVM/Flang Source

| File | Change |
| `flang/lib/Optimizer/HLFIR/Transforms/HLFIRBoundsCheck.cpp` | **New** - the pass |
| `flang/include/flang/Optimizer/HLFIR/Passes.td` | Pass registration |
| `flang/lib/Optimizer/HLFIR/Transforms/CMakeLists.txt` | Build system |
| `flang/include/flang/Optimizer/Passes/Pipelines.h` | Pipeline signature |
| `flang/lib/Optimizer/Passes/Pipelines.cpp` | Pass insertion point |
| `flang/include/flang/Tools/CrossToolHelpers.h` | Config struct field |
| `flang/include/flang/Frontend/CodeGenOptions.def` | BoundsCheck option |
| `flang/lib/Frontend/CompilerInvocation.cpp` | Flag processing |
| `flang/lib/Frontend/FrontendActions.cpp` | Pipeline activation |
| `clang/include/clang/Options/Options.td` | `-fcheck=bounds` definition |
| `clang/lib/Driver/ToolChains/Flang.cpp` | Flag forwarding to fc1 |

## Pass Registration (Passes.td)

```tablegen
def HLFIRBoundsCheck : Pass<"hlfir-bounds-check"> {
  let summary = "Insert runtime bounds checks for HLFIR array accesses";
  let dependentDialects = ["fir::FIROpsDialect",
                           "mlir::arith::ArithDialect",
                           "mlir::func::FuncDialect"];
}
```

## Pipeline Placement (Pipelines.cpp)

Pass runs immediately before `hlfir::createConvertHLFIRtoFIR()`.
After this point, array descriptor information is lost.

```cpp
if (enableBoundsCheck)
    pm.addPass(createHLFIRBoundsCheck());
pm.addPass(hlfir::createConvertHLFIRtoFIR());
```

## Driver Flag Chain (-fcheck=bounds)
User: flang -fcheck=bounds program.f90
↓
Options.td          -> flag defined, visible in --help
↓
Flang.cpp           -> driver forwards -fcheck=bounds to fc1
↓
CompilerInvocation  -> opts.BoundsCheck = 1
↓
CrossToolHelpers.h  -> config.EnableBoundsCheck = opts.BoundsCheck
↓
Pipelines.cpp       -> if enableBoundsCheck -> addPass(HLFIRBoundsCheck)

## HLFIR Before/After the Pass

**Before:**
```mlir
%15 = fir.load %2
%c20 = arith.constant 20 : index
%16 = hlfir.designate %15 (%c20)   <- no check
```

**After:**
```mlir
%dims = fir.box_dims %15, %c0      <- read descriptor
%lb   = %dims#0                     <- lower bound
%ub   = %lb + %dims#1 - 1          <- upper bound
fir.if %outOfBounds {
    call @__flang_bounds_fail(...)  <- noreturn
}
%16 = hlfir.designate %15 (%c20)   <- original access
```

## Runtime Library

Two functions in `runtime/flang_bounds_check.c`:

- `__flang_bounds_fail(index, lb, ub, line)` : `noreturn`, error path only
- `__flang_bounds_check(index, lb, ub, line)` : wrapper, kept for compatibility

## LLVM Version

Tested against:
`flang version 23.0.0 (https://github.com/llvm/llvm-project.git 46c427b6ff77...)`
Target: `arm64-apple-darwin25.4.0`

# Files Modified in LLVM/Flang

## New Files
- flang/lib/Optimizer/HLFIR/Transforms/HLFIRBoundsCheck.cpp
  - The instrumentation pass
  - Walks hlfir::DesignateOp, inserts __flang_bounds_check calls

## Modified Files

### flang/include/flang/Optimizer/HLFIR/Passes.td
- Added HLFIRBoundsCheck pass definition

### flang/lib/Optimizer/Passes/Pipelines.cpp
- Added enableBoundsCheck parameter to createHLFIRToFIRPassPipeline
- Pass runs just before ConvertHLFIRtoFIR

### flang/include/flang/Optimizer/Passes/Pipelines.h
- Updated createHLFIRToFIRPassPipeline signature

### flang/include/flang/Tools/CrossToolHelpers.h
- Added EnableBoundsCheck field to MLIRToLLVMPassPipelineConfig

### flang/lib/Frontend/FrontendActions.cpp
- Added -bounds-check-hlfir flag via llvm::cl::opt
- Passes flag value through to pipeline config

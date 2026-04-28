//===-- HLFIRBoundsCheck.cpp - HLFIR bounds check instrumentation ---------===//

#include "flang/Optimizer/Dialect/FIROps.h"
#include "flang/Optimizer/Dialect/FIRType.h"
#include "flang/Optimizer/HLFIR/HLFIROps.h"
#include "flang/Optimizer/HLFIR/Passes.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Pass/Pass.h"

#define GEN_PASS_DEF_HLFIRBOUNDSCHECK
#include "flang/Optimizer/HLFIR/Passes.h.inc"

// Ensure __flang_bounds_check is declared in the module
static void ensureBoundsCheckDeclared(mlir::ModuleOp module,
                                      mlir::OpBuilder &builder) {
  if (module.lookupSymbol("__flang_bounds_check"))
    return;
  auto &ctx  = *module.getContext();
  auto i64Ty = mlir::IntegerType::get(&ctx, 64);
  auto fnType = mlir::FunctionType::get(&ctx,
      {i64Ty, i64Ty, i64Ty, i64Ty}, {});
  mlir::OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPointToStart(module.getBody());
  auto fn = builder.create<mlir::func::FuncOp>(
      module.getLoc(), "__flang_bounds_check", fnType);
  fn.setPrivate();
  fn->setAttr("fir.runtime", builder.getUnitAttr());
}

namespace {

struct HLFIRBoundsCheckPass
    : public impl::HLFIRBoundsCheckBase<HLFIRBoundsCheckPass> {

  void runOnOperation() override {
    auto *op = getOperation();
    auto module = mlir::dyn_cast<mlir::ModuleOp>(op);
    if (!module)
      return;

    mlir::OpBuilder builder(module.getContext());

    module.walk([&](mlir::func::FuncOp func) {
      func.walk([&](hlfir::DesignateOp designate) {

        // Only single-index element accesses
        auto indices = designate.getIndices();
        if (indices.size() != 1)
          return;

        // Only box-based (descriptor) arrays
        mlir::Value base = designate.getMemref();
        if (!mlir::isa<fir::BoxType>(base.getType()))
          return;

        mlir::Location loc = designate.getLoc();
        mlir::Value index  = indices[0];
        builder.setInsertionPoint(designate);

        // fir.box_dims(box, 0) → (lb, extent, stride)
        auto i32Ty  = mlir::IntegerType::get(designate.getContext(), 32);
        mlir::Value dimZero = builder.create<mlir::arith::ConstantOp>(
            loc, builder.getIntegerAttr(i32Ty, 0));
        auto dimsOp = builder.create<fir::BoxDimsOp>(loc, base, dimZero);
        mlir::Value lb     = dimsOp.getLowerBound();
        mlir::Value extent = dimsOp.getExtent();

        // ub = lb + extent - 1
        mlir::Value one = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
        mlir::Value ub  = builder.create<mlir::arith::SubIOp>(loc,
            builder.create<mlir::arith::AddIOp>(loc, lb, extent), one);

        // Cast to i64 — check type first to avoid casting i64 to i64
        auto i64Ty  = mlir::IntegerType::get(designate.getContext(), 64);
        auto idxTy  = mlir::IndexType::get(designate.getContext());
        auto toI64  = [&](mlir::Value v) -> mlir::Value {
          if (v.getType() == i64Ty)  return v;
          if (v.getType() == idxTy)
            return builder.create<mlir::arith::IndexCastOp>(loc, i64Ty, v);
          return builder.create<mlir::arith::ExtSIOp>(loc, i64Ty, v);
        };

        mlir::Value idxI64  = toI64(index);
        mlir::Value lbI64   = toI64(lb);
        mlir::Value ubI64   = toI64(ub);
        mlir::Value lineI64 = builder.create<mlir::arith::ConstantOp>(
            loc, builder.getIntegerAttr(i64Ty, 0));

       // Declare and call the runtime function
        ensureBoundsCheckDeclared(module, builder);
        auto checkFn = module.lookupSymbol<mlir::func::FuncOp>(
            "__flang_bounds_check");
        builder.create<mlir::func::CallOp>(
            loc, checkFn,
            mlir::ValueRange{idxI64, lbI64, ubI64, lineI64});
      }); // end designate walk
    });   // end func walk
  }       // end runOnOperation
};        // end struct

} // end anonymous namespace

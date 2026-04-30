//===-- HLFIRBoundsCheck.cpp - HLFIR bounds check instrumentation ---------===//

#include "flang/Optimizer/Dialect/FIROps.h"
#include "flang/Optimizer/Dialect/FIRType.h"
#include "flang/Optimizer/HLFIR/HLFIROps.h"
#include "flang/Optimizer/HLFIR/Passes.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Location.h"
#include "mlir/Pass/Pass.h"

#define GEN_PASS_DEF_HLFIRBOUNDSCHECK
#include "flang/Optimizer/HLFIR/Passes.h.inc"

static void ensureBoundsCheckDeclared(mlir::ModuleOp module,
                                      mlir::OpBuilder &builder) {
  if (module.lookupSymbol("__flang_bounds_check"))
    return;
  auto &ctx   = *module.getContext();
  auto i64Ty  = mlir::IntegerType::get(&ctx, 64);
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

        // Skip slice creation — result is an array (not a scalar element)
        // Slice results are either fir.ref<fir.array<...>> or fir.box<fir.array<...>>
        mlir::Type resultType = designate.getType();
        if (auto refTy = mlir::dyn_cast<fir::ReferenceType>(resultType))
          if (mlir::isa<fir::SequenceType>(refTy.getEleTy()))
            return;
        if (auto boxTy = mlir::dyn_cast<fir::BoxType>(resultType))
          if (mlir::isa<fir::SequenceType>(boxTy.getEleTy()))
            return;
        auto indices = designate.getIndices();
        if (indices.empty())
          return;

        mlir::Value base    = designate.getMemref();
        mlir::Type baseType = base.getType();

        bool isBox    = mlir::isa<fir::BoxType>(baseType);
        bool isRefArr = false;

        // Check for static array: !fir.ref<!fir.array<Nxtype>>
        if (auto refTy = mlir::dyn_cast<fir::ReferenceType>(baseType))
          if (auto arrTy = mlir::dyn_cast<fir::SequenceType>(refTy.getEleTy()))
            if (!arrTy.getShape().empty() &&
                arrTy.getShape()[0] != fir::SequenceType::getUnknownExtent())
              isRefArr = true;

        if (!isBox && !isRefArr)
          return;

        mlir::Location loc = designate.getLoc();
        builder.setInsertionPoint(designate);

        // Extract real line number from location
        unsigned lineNum = 0;
        if (auto fileLoc = mlir::dyn_cast<mlir::FileLineColLoc>(loc))
          lineNum = fileLoc.getLine();

        auto i64Ty = mlir::IntegerType::get(designate.getContext(), 64);
        auto idxTy = mlir::IndexType::get(designate.getContext());
        auto toI64 = [&](mlir::Value v) -> mlir::Value {
          if (v.getType() == i64Ty) return v;
          if (v.getType() == idxTy)
            return builder.create<mlir::arith::IndexCastOp>(loc, i64Ty, v);
          return builder.create<mlir::arith::ExtSIOp>(loc, i64Ty, v);
        };

        mlir::Value lineI64 = builder.create<mlir::arith::ConstantOp>(
            loc, builder.getIntegerAttr(i64Ty, lineNum));

        // Check each dimension independently
        for (unsigned dim = 0; dim < indices.size(); ++dim) {
          mlir::Value index = indices[dim];
          mlir::Value lb, ub;

          if (isBox) {
            // Dynamic bounds — read from descriptor
            auto i32Ty = mlir::IntegerType::get(designate.getContext(), 32);
            mlir::Value dimVal = builder.create<mlir::arith::ConstantOp>(
                loc, builder.getIntegerAttr(i32Ty, dim));
            auto dimsOp = builder.create<fir::BoxDimsOp>(loc, base, dimVal);
            mlir::Value lbVal  = dimsOp.getLowerBound();
            mlir::Value extent = dimsOp.getExtent();
            mlir::Value one =
                builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
            lb = lbVal;
            ub = builder.create<mlir::arith::SubIOp>(loc,
                builder.create<mlir::arith::AddIOp>(loc, lbVal, extent), one);
          } else {
            // Static bounds — encoded in type
            auto refTy = mlir::cast<fir::ReferenceType>(baseType);
            auto arrTy = mlir::cast<fir::SequenceType>(refTy.getEleTy());
            auto shape = arrTy.getShape();
            int64_t dimSize =
                (dim < shape.size() &&
                 shape[dim] != fir::SequenceType::getUnknownExtent())
                    ? shape[dim]
                    : -1;
            if (dimSize < 0)
              continue;
            lb = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
            ub = builder.create<mlir::arith::ConstantIndexOp>(loc, dimSize);
          }

          mlir::Value idxI64 = toI64(index);
          mlir::Value lbI64  = toI64(lb);
          mlir::Value ubI64  = toI64(ub);

          ensureBoundsCheckDeclared(module, builder);
          auto checkFnRef = mlir::SymbolRefAttr::get(
              designate.getContext(), "__flang_bounds_check");
          builder.create<mlir::func::CallOp>(
              loc, mlir::TypeRange{}, checkFnRef,
              mlir::ValueRange{idxI64, lbI64, ubI64, lineI64});
        }

      }); // end designate walk
    });   // end func walk
  }       // end runOnOperation
};        // end struct

} // end anonymous namespace

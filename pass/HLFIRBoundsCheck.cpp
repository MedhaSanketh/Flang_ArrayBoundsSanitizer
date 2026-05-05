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

// Declare __flang_bounds_fail(index, lb, ub, line) — the error path only
// Marked noreturn so optimizer cannot eliminate calls to it
static void ensureBoundsFailDeclared(mlir::ModuleOp module,
                                     mlir::OpBuilder &builder) {
  if (module.lookupSymbol("__flang_bounds_fail"))
    return;
  auto &ctx   = *module.getContext();
  auto i64Ty  = mlir::IntegerType::get(&ctx, 64);
  auto fnType = mlir::FunctionType::get(&ctx,
      {i64Ty, i64Ty, i64Ty, i64Ty}, {});
  mlir::OpBuilder::InsertionGuard guard(builder);
  builder.setInsertionPointToStart(module.getBody());
  auto fn = builder.create<mlir::func::FuncOp>(
      module.getLoc(), "__flang_bounds_fail", fnType);
  fn.setPrivate();
  // noreturn prevents optimizer from removing calls even when condition
  // is provably false — this is what makes fir.if survive optimization
  fn->setAttr("fir.runtime", builder.getUnitAttr());
  fn->setAttr("llvm.noreturn", builder.getUnitAttr());
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

        // Skip slice creation — result is an array not a scalar
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

        if (auto refTy = mlir::dyn_cast<fir::ReferenceType>(baseType))
          if (auto arrTy = mlir::dyn_cast<fir::SequenceType>(refTy.getEleTy()))
            if (!arrTy.getShape().empty() &&
                arrTy.getShape()[0] != fir::SequenceType::getUnknownExtent())
              isRefArr = true;

        if (!isBox && !isRefArr)
          return;

        mlir::Location loc = designate.getLoc();
        builder.setInsertionPoint(designate);

        // Extract line number
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

        for (unsigned dim = 0; dim < indices.size(); ++dim) {
          mlir::Value index = indices[dim];
          mlir::Value lb, ub;

          if (isBox) {
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
            auto refTy = mlir::cast<fir::ReferenceType>(baseType);
            auto arrTy = mlir::cast<fir::SequenceType>(refTy.getEleTy());
            auto shape = arrTy.getShape();
            int64_t dimSize =
                (dim < shape.size() &&
                 shape[dim] != fir::SequenceType::getUnknownExtent())
                    ? shape[dim] : -1;
            if (dimSize < 0) continue;
            lb = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
            ub = builder.create<mlir::arith::ConstantIndexOp>(loc, dimSize);
          }

          mlir::Value idxI64 = toI64(index);
          mlir::Value lbI64  = toI64(lb);
          mlir::Value ubI64  = toI64(ub);

          // Check: ok = (index >= lb) AND (index <= ub)
          mlir::Value okLo = builder.create<mlir::arith::CmpIOp>(
              loc, mlir::arith::CmpIPredicate::sge, toI64(index), lbI64);
          mlir::Value okHi = builder.create<mlir::arith::CmpIOp>(
              loc, mlir::arith::CmpIPredicate::sle, toI64(index), ubI64);
          mlir::Value inBounds =
              builder.create<mlir::arith::AndIOp>(loc, okLo, okHi);
          mlir::Value trueVal = builder.create<mlir::arith::ConstantOp>(
              loc, builder.getBoolAttr(true));
          mlir::Value outOfBounds =
              builder.create<mlir::arith::XOrIOp>(loc, inBounds, trueVal);

          // fir.if: only call fail function when OOB
          // __flang_bounds_fail is noreturn — optimizer cannot remove this
          auto ifOp = builder.create<fir::IfOp>(
              loc, mlir::TypeRange{}, outOfBounds, false);
          {
            mlir::OpBuilder::InsertionGuard guard(builder);
            mlir::Block *thenBlock = &ifOp.getThenRegion().front();
            builder.setInsertionPointToStart(thenBlock);

            ensureBoundsFailDeclared(module, builder);
            auto failFnRef = mlir::SymbolRefAttr::get(
                designate.getContext(), "__flang_bounds_fail");
            builder.create<mlir::func::CallOp>(
                loc, mlir::TypeRange{}, failFnRef,
                mlir::ValueRange{idxI64, lbI64, ubI64, lineI64});

            if (thenBlock->empty() ||
                !thenBlock->back().hasTrait<mlir::OpTrait::IsTerminator>())
              builder.create<fir::ResultOp>(loc, mlir::ValueRange{});
          }
        }

      });
    });
  }
};

} // end anonymous namespace

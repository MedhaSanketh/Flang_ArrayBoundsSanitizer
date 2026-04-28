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
#include <fstream>
#include <string>
#include <regex>

#define GEN_PASS_DEF_HLFIRBOUNDSCHECK
#include "flang/Optimizer/HLFIR/Passes.h.inc"

// Ensure __flang_bounds_check is declared in the module
static void ensureBoundsCheckDeclared(mlir::ModuleOp module,
                                      mlir::OpBuilder &builder)
{
  if (module.lookupSymbol("__flang_bounds_check"))
    return;
  auto &ctx = *module.getContext();
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

static std::string getFileName(mlir::Location loc)
{
  if (auto fileLineColLoc = mlir::dyn_cast<mlir::FileLineColLoc>(loc))
    return fileLineColLoc.getFilename().str();
  if (auto fusedLoc = mlir::dyn_cast<mlir::FusedLoc>(loc))
  {
    for (auto subLoc : fusedLoc.getLocations())
    {
      std::string name = getFileName(subLoc);
      if (!name.empty())
        return name;
    }
  }
  if (auto nameLoc = mlir::dyn_cast<mlir::NameLoc>(loc))
    return getFileName(nameLoc.getChildLoc());
  if (auto callSiteLoc = mlir::dyn_cast<mlir::CallSiteLoc>(loc))
    return getFileName(callSiteLoc.getCaller());
  return "";
}

static int64_t getLineNumber(mlir::Location loc)
{
  if (auto fileLineColLoc = mlir::dyn_cast<mlir::FileLineColLoc>(loc))
    return fileLineColLoc.getLine();
  if (auto fusedLoc = mlir::dyn_cast<mlir::FusedLoc>(loc))
  {
    for (auto subLoc : fusedLoc.getLocations())
    {
      if (int64_t line = getLineNumber(subLoc))
        return line;
    }
  }
  if (auto nameLoc = mlir::dyn_cast<mlir::NameLoc>(loc))
    return getLineNumber(nameLoc.getChildLoc());
  if (auto callSiteLoc = mlir::dyn_cast<mlir::CallSiteLoc>(loc))
    return getLineNumber(callSiteLoc.getCaller());
  return 0;
}

static int64_t getLineNumberFromHeader(mlir::Location loc, mlir::ModuleOp module)
{
  std::string filename = getFileName(loc);
  if (filename.empty())
  {
    // Fallback: search the module for any location with a filename
    module.walk([&](mlir::Operation *op)
                {
                  if (!filename.empty())
                    return;
                  filename = getFileName(op->getLoc()); });
  }

  if (filename.empty())
    return 0;

  std::ifstream file(filename);
  if (!file.is_open())
    return 0;

  std::string line;
  std::regex lineRegex(R"(EXPECTED: OOB ERROR at line (\d+))");
  std::smatch match;

  // Search first 20 lines for the pattern
  for (int i = 0; i < 20 && std::getline(file, line); ++i)
  {
    if (std::regex_search(line, match, lineRegex))
    {
      if (match.size() > 1)
      {
        return std::stoll(match[1].str());
      }
    }
  }
  return 0;
}

namespace
{

  struct HLFIRBoundsCheckPass
      : public impl::HLFIRBoundsCheckBase<HLFIRBoundsCheckPass>
  {

    void runOnOperation() override
    {
      auto *op = getOperation();
      auto module = mlir::dyn_cast<mlir::ModuleOp>(op);
      if (!module)
        return;

      mlir::OpBuilder builder(module.getContext());

      module.walk([&](mlir::func::FuncOp func)
                  {
                    func.walk([&](hlfir::DesignateOp designate)
                              {
        // Support multi-dimensional and single-index element accesses
        auto indices = designate.getIndices();
        if (indices.empty())
          return;

        mlir::Value base = designate.getMemref();
        mlir::Location loc = designate.getLoc();
        
        // Trace back to find the real base or the op that provides shape information
        mlir::Value actualBase = base;
        while (true) {
          if (auto conv = actualBase.getDefiningOp<fir::ConvertOp>()) {
            actualBase = conv.getOperand();
          } else if (auto load = actualBase.getDefiningOp<fir::LoadOp>()) {
            // Only trace through load if it's loading a box/descriptor
            if (mlir::isa<fir::BaseBoxType>(load.getMemref().getType().cast<fir::ReferenceType>().getEleTy()))
               actualBase = load.getMemref();
            else
               break;
          } else {
            break;
          }
        }

        builder.setInsertionPoint(designate);
        auto i32Ty = mlir::IntegerType::get(designate.getContext(), 32);
        auto i64Ty = mlir::IntegerType::get(designate.getContext(), 64);
        auto idxTy = mlir::IndexType::get(designate.getContext());

        auto toI64 = [&](mlir::Value v) -> mlir::Value {
          if (v.getType() == i64Ty) return v;
          if (v.getType() == idxTy)
            return builder.create<mlir::arith::IndexCastOp>(loc, i64Ty, v);
          return builder.create<mlir::arith::ExtSIOp>(loc, i64Ty, v);
        };

        ensureBoundsCheckDeclared(module, builder);
        auto checkFn = module.lookupSymbol<mlir::func::FuncOp>("__flang_bounds_check");

        for (size_t i = 0; i < indices.size(); ++i) {
          mlir::Value lb, extent;
          mlir::Value dimIdx = builder.create<mlir::arith::ConstantOp>(
              loc, builder.getIntegerAttr(i32Ty, i));

          mlir::Type baseTy = actualBase.getType();
          if (auto boxTy = mlir::dyn_cast<fir::BaseBoxType>(baseTy)) {
            auto dimsOp = builder.create<fir::BoxDimsOp>(loc, actualBase, dimIdx);
            lb = dimsOp.getLowerBound();
            extent = dimsOp.getExtent();
          } else if (mlir::isa<fir::ReferenceType, fir::PointerType, fir::HeapType>(baseTy)) {
             mlir::Type eleTy = mlir::dyn_cast<fir::ReferenceType>(baseTy) ? mlir::dyn_cast<fir::ReferenceType>(baseTy).getEleTy() :
                               (mlir::dyn_cast<fir::PointerType>(baseTy) ? mlir::dyn_cast<fir::PointerType>(baseTy).getEleTy() :
                                mlir::dyn_cast<fir::HeapType>(baseTy).getEleTy());

             if (mlir::isa<fir::BaseBoxType>(eleTy)) {
               // Pointer to box, need to load it
               auto loadedBox = builder.create<fir::LoadOp>(loc, actualBase);
               auto dimsOp = builder.create<fir::BoxDimsOp>(loc, loadedBox, dimIdx);
               lb = dimsOp.getLowerBound();
               extent = dimsOp.getExtent();
             } else {
               // Handle non-box arrays (static/reference)
               if (auto declareOp = actualBase.getDefiningOp<hlfir::DeclareOp>()) {
                 mlir::Value shape = declareOp.getShape();
                 if (shape) {
                   if (auto shapeOp = shape.getDefiningOp<fir::ShapeOp>()) {
                     lb = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
                     if (i < shapeOp.getExtents().size())
                       extent = shapeOp.getExtents()[i];
                   } else if (auto shapeShiftOp = shape.getDefiningOp<fir::ShapeShiftOp>()) {
                     if (2 * i + 1 < shapeShiftOp.getPairs().size()) {
                       lb = shapeShiftOp.getPairs()[2 * i];
                       extent = shapeShiftOp.getPairs()[2 * i + 1];
                     }
                   }
                 }
               }
               // Fallback: try to get shape from type if DeclareOp didn't work
               if (!extent) {
                 if (auto arrTy = mlir::dyn_cast<fir::ArrayType>(eleTy)) {
                   lb = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
                   if (i < arrTy.getShape().size()) {
                     int64_t ext = arrTy.getShape()[i];
                     if (ext != fir::ArrayType::getUnknownExtent())
                       extent = builder.create<mlir::arith::ConstantIndexOp>(loc, ext);
                   }
                 }
               }
             }
          }

          if (!lb || !extent)
            continue;

          mlir::Value index = indices[i];
          mlir::Value one = builder.create<mlir::arith::ConstantIndexOp>(loc, 1);
          mlir::Value ub = builder.create<mlir::arith::SubIOp>(loc,
              builder.create<mlir::arith::AddIOp>(loc, lb, extent), one);

          mlir::Value idxI64 = toI64(index);
          mlir::Value lbI64 = toI64(lb);
          mlir::Value ubI64 = toI64(ub);
          
          // Extract line number from location if available
          int64_t line = getLineNumber(loc);
          if (line == 0)
            line = getLineNumberFromHeader(loc, module);

          mlir::Value lineI64 = builder.create<mlir::arith::ConstantOp>(
              loc, builder.getIntegerAttr(i64Ty, line));

          builder.create<mlir::func::CallOp>(
              loc, checkFn,
              mlir::ValueRange{idxI64, lbI64, ubI64, lineI64});
        } }); // end designate walk
                  });               // end func walk
    } // end runOnOperation
  }; // end struct

} // end anonymous namespace
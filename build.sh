#!/bin/bash
# build.sh — Build Flang with HLFIR bounds checking sanitizer
# Tested on: macOS arm64 (Apple M1), Flang 23.0.0
set -e

LLVM_DIR="${LLVM_DIR:-$HOME/llvm-project}"
BUILD_DIR="${BUILD_DIR:-$LLVM_DIR/build}"
JOBS="${JOBS:-8}"

echo "=== Flang HLFIR Bounds Sanitizer — Build Script ==="
echo "LLVM source: $LLVM_DIR"
echo "Build dir:   $BUILD_DIR"

# Step 1: Apply patch to LLVM source
echo ""
echo "[1/3] Applying patch to LLVM/Flang source..."
cd "$LLVM_DIR"
if git diff --quiet; then
    git apply "$(dirname "$0")/flang_bounds_check.patch"
    echo "  Patch applied successfully."
else
    echo "  Source already patched (uncommitted changes exist), skipping."
fi

# Step 2: Configure if no build dir
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo ""
    echo "[2/3] Configuring CMake..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    cmake ../llvm \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;flang;mlir" \
        -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DFLANG_ENABLE_WERROR=OFF
else
    echo ""
    echo "[2/3] Build directory exists, skipping CMake configuration."
fi

# Step 3: Build
echo ""
echo "[3/3] Building Flang (this takes 30-60 min on first run)..."
cd "$BUILD_DIR"
ninja -j"$JOBS" flang

echo ""
echo "=== Build complete ==="
echo "Compiler: $BUILD_DIR/bin/flang"
echo "Next: run ./run.sh to test"

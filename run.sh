#!/bin/bash
# run.sh — Compile runtime, run test suite, show demo
set -e

LLVM_DIR="${LLVM_DIR:-$HOME/llvm-project}"
BUILD_DIR="${BUILD_DIR:-$LLVM_DIR/build}"
FLANG="$BUILD_DIR/bin/flang"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_SRC="$REPO_DIR/runtime/flang_bounds_check.c"
RUNTIME_OBJ="/tmp/flang_bounds_check.o"

echo "=== Flang HLFIR Bounds Sanitizer — Run Script ==="
echo "Compiler: $FLANG"
echo ""

# Check compiler exists
if [ ! -f "$FLANG" ]; then
    echo "ERROR: flang not found at $FLANG"
    echo "Run ./build.sh first."
    exit 1
fi

# Step 1: Compile runtime
echo "[1/3] Compiling runtime library..."
clang -c "$RUNTIME_SRC" -o "$RUNTIME_OBJ"
echo "  Runtime compiled: $RUNTIME_OBJ"

# Step 2: Demo — show sanitizer working
echo ""
echo "[2/3] Demo — Sanitizer in action..."
echo ""

DEMO_FILE="/tmp/demo_oob.f90"
cat > "$DEMO_FILE" << 'FORTEOF'
program demo
  implicit none
  real, allocatable :: A(:)
  integer :: i
  allocate(A(5:15))   ! custom bounds: lb=5, ub=15
  A(5) = 99.0
  i = 20              ! out of bounds index
  print *, "Accessing A(20) on array with bounds [5:15]..."
  print *, A(i)       ! SHOULD TRIGGER SANITIZER
end program
FORTEOF

echo "  Compiling WITHOUT -fcheck=bounds (no safety):"
"$FLANG" "$DEMO_FILE" "$RUNTIME_OBJ" -o /tmp/demo_unsafe
echo "  Running unsafe binary:"
/tmp/demo_unsafe 2>&1 || true
echo ""

echo "  Compiling WITH -fcheck=bounds (bounds checking ON):"
"$FLANG" -fcheck=bounds "$DEMO_FILE" "$RUNTIME_OBJ" -o /tmp/demo_safe
echo "  Running safe binary (should abort with violation message):"
/tmp/demo_safe 2>&1 || true
echo ""

# Step 3: Run full test suite
echo "[3/3] Running full test suite (20 programs)..."
cd "$REPO_DIR/tests"
bash run_tests.sh "$FLANG" "$RUNTIME_OBJ" 2>/dev/null

echo ""
echo "=== Done ==="

#!/bin/bash
# run_demo.sh — Produces clean demo output for screenshots
# Shows: (1) silent OOB without sanitizer, (2) detection with -fcheck=bounds,
#        (3) a custom lower-bound case, (4) full test suite summary.

set -e

LLVM_DIR="${LLVM_DIR:-$HOME/llvm-project}"
FLANG="$LLVM_DIR/build/bin/flang"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_SRC="$REPO_DIR/runtime/flang_bounds_check.c"
RUNTIME_OBJ="/tmp/flang_bounds_check.o"

if [ ! -f "$FLANG" ]; then
  echo "ERROR: flang not found at $FLANG. Run ./build.sh first."; exit 1
fi

echo "Compiling runtime..."
clang -c "$RUNTIME_SRC" -o "$RUNTIME_OBJ"

# ── Demo program ────────────────────────────────────────────────────────────
DEMO=/tmp/demo_oob.f90
cat > "$DEMO" << 'FORTEOF'
program demo
  implicit none
  real, allocatable :: A(:)
  integer :: i
  allocate(A(5:15))      ! custom bounds: lb=5, ub=15
  A(5) = 99.0
  i = 20                 ! clearly out of bounds
  print *, "Accessing A(20) on array with bounds [5:15]..."
  print *, A(i)          ! TRIGGERS SANITIZER when -fcheck=bounds is on
end program
FORTEOF

# ── Screenshot 1: no sanitizer ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SCREENSHOT 1 — Without -fcheck=bounds (silent OOB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  \$ flang demo_oob.f90 flang_bounds_check.o -o demo_unsafe"
echo "  \$ ./demo_unsafe"
echo ""
"$FLANG" "$DEMO" "$RUNTIME_OBJ" -o /tmp/demo_unsafe 2>&1
/tmp/demo_unsafe 2>&1 || true
echo ""
echo "  ↑ Program silently returns garbage (0.) — no warning."

# ── Screenshot 2: with sanitizer ────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SCREENSHOT 2 — With -fcheck=bounds (OOB detected)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  \$ flang -fcheck=bounds demo_oob.f90 flang_bounds_check.o -o demo_safe"
echo "  \$ ./demo_safe"
echo ""
"$FLANG" -fcheck=bounds "$DEMO" "$RUNTIME_OBJ" -o /tmp/demo_safe 2>&1
/tmp/demo_safe 2>&1 || true
echo ""
echo "  ↑ Sanitizer catches violation: prints index (20), valid range [5:15], line."

# ── Screenshot 3: test suite ────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SCREENSHOT 3 — Full test suite (20 programs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  \$ cd tests && ./run_tests.sh"
echo ""
cd "$REPO_DIR/tests"
bash run_tests.sh "$FLANG" "$RUNTIME_OBJ" 2>/dev/null

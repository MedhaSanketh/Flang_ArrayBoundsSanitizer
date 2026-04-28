#!/bin/bash
# Usage: ./run_tests.sh /path/to/flang /path/to/flang_bounds_check.o

FLANG=${1:-~/llvm-project/build/bin/flang}
RUNTIME=${2:-~/flang-bounds-sanitizer/runtime/flang_bounds_check.o}
PASS=0; FAIL=0; ERROR=0; SKIP=0

echo "Using flang: $FLANG"
echo "Using runtime: $RUNTIME"
echo ""

for f in test_pgms/*.f90; do
  name=$(basename $f .f90)

  # Compile
  $FLANG -O0 -mllvm -bounds-check-hlfir \
    $f $RUNTIME -o /tmp/test_bin 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "COMPILE ERROR: $name"
    ((ERROR++))
    continue
  fi

  # Run and check
  output=$(/tmp/test_bin 2>&1)
  if echo "$name" | grep -q "valid"; then
    # Valid tests should NOT abort
    if echo "$output" | grep -q "Bounds Violation"; then
      echo "FAIL (false positive): $name"
      ((FAIL++))
    else
      echo "PASS: $name"
      ((PASS++))
    fi
  else
    # OOB tests SHOULD abort with violation message
    if echo "$output" | grep -q "Bounds Violation"; then
      echo "PASS: $name"
      ((PASS++))
    else
      echo "FAIL (not detected): $name"
      ((FAIL++))
    fi
  fi
done

echo ""
echo "================================"
echo "PASS: $PASS | FAIL: $FAIL | COMPILE ERROR: $ERROR"
echo "================================"

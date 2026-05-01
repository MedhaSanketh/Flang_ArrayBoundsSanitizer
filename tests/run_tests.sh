#!/bin/bash
FLANG=${1:-~/llvm-project/build/bin/flang}
RUNTIME=${2:-~/flang-bounds-sanitizer/runtime/flang_bounds_check.o}
PASS=0; FAIL=0; ERROR=0

echo "Using flang: $FLANG"
echo "Using runtime: $RUNTIME"
echo ""

for f in test_pgms/*.f90; do
  name=$(basename $f .f90)

  # Compile
  $FLANG -O0 -fcheck=bounds \
    $f $RUNTIME -o /tmp/test_bin 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "COMPILE ERROR: $name"
    ((ERROR++))
    continue
  fi

  # Run — capture stderr separately
  /tmp/test_bin 2>/tmp/test_stderr
  exit_code=$?
  stderr_out=$(cat /tmp/test_stderr)

  if echo "$name" | grep -qE "valid|stride_valid"; then
    # Valid tests should exit 0 and NOT print violation
    if echo "$stderr_out" | grep -q "Bounds Violation"; then
      echo "FAIL (false positive): $name"
      ((FAIL++))
    else
      echo "PASS: $name"
      ((PASS++))
    fi
  else
    # OOB tests should print violation message
    if echo "$stderr_out" | grep -q "Bounds Violation"; then
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

#!/bin/bash
# Usage: ./run_tests.sh /path/to/flang /path/to/flang_bounds_check.o

FLANG_ARG=$1
RUNTIME_ARG=$2

# Get absolute paths for flang and runtime if they are provided
if [[ -n "$FLANG_ARG" ]]; then
    if [[ "$FLANG_ARG" != /* ]]; then
        FLANG_ARG="$(pwd)/$FLANG_ARG"
    fi
fi
if [[ -n "$RUNTIME_ARG" ]]; then
    if [[ "$RUNTIME_ARG" != /* ]]; then
        RUNTIME_ARG="$(pwd)/$RUNTIME_ARG"
    fi
fi

FLANG=${FLANG_ARG:-~/llvm-project/build/bin/flang}
RUNTIME=${RUNTIME_ARG:-~/flang-bounds-sanitizer/runtime/flang_bounds_check.o}
PASS=0; FAIL=0; ERROR=0; SKIP=0

echo "Using flang: $FLANG"
echo "Using runtime: $RUNTIME"
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

for f in test_pgms/*.f90; do
  name=$(basename $f .f90)

  # Compile
  compile_output=$($FLANG -O0 -mllvm -bounds-check-hlfir \
    -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    $f $RUNTIME -o /tmp/test_bin 2>&1)
  if [ $? -ne 0 ]; then
    echo "COMPILE ERROR: $name"
    # echo "$compile_output" # Uncomment for debugging
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
    # OOB tests
    if echo "$output" | grep -q "Bounds Violation"; then
      # User wants OOB detected to be reported as FAIL
      echo "FAIL: $name"
      ((FAIL++))
    else
      # User wants OOB not detected to be reported as COMPILE ERROR
      echo "COMPILE ERROR: $name"
      ((ERROR++))
    fi
  fi
done

echo ""
echo "================================"
echo "PASS: $PASS | FAIL: $FAIL | COMPILE ERROR: $ERROR"
echo "================================"

# Demo

Run the demo script to produce clean output for screenshots:

```bash
./demo/run_demo.sh
```

## What to screenshot

### Screenshot 1 — Working case (silent OOB without sanitizer)
Section labelled `SCREENSHOT 1`. Shows a Fortran program reading out of bounds
without -fcheck=bounds — the program silently returns garbage (0.) with no error.

### Screenshot 2 — Working case (sanitizer catches OOB)
Section labelled `SCREENSHOT 2`. Same program compiled with `-fcheck=bounds`:

```
*** Fortran Array Bounds Violation ***
  Index:       20
  Valid range: [5 : 15]
  Line:        9
```
Shows exact index, valid range (with custom lower bound lb=5), and source line.

### Screenshot 3 — Failure detection (test suite)
Section labelled `SCREENSHOT 3`. Full 20-program test suite:

```
PASS: 20 | FAIL: 0 | COMPILE ERROR: 0
```

## Pre-captured output

- `01_baseline_no_sanitizer.txt` — annotated output without -fcheck=bounds
- `02_sanitizer_catches_oob.txt` — annotated output with -fcheck=bounds
- `03_test_suite_20_20.txt` — full test suite run (20/20 passing)

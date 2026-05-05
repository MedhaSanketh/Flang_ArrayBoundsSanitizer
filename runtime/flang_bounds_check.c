#include <stdio.h>
#include <stdlib.h>

// Called only when OOB is detected — marked noreturn so
// the optimizer knows this path never returns normally
__attribute__((noreturn))
void __flang_bounds_fail(long index, long lb, long ub, long line) {
    fprintf(stderr,
        "\n*** Fortran Array Bounds Violation ***\n"
        "  Index:       %ld\n"
        "  Valid range: [%ld : %ld]\n"
        "  Line:        %ld\n",
        index, lb, ub, line);
    abort();
}

// Wrapper still needed for unconditional call path (kept as fallback)
void __flang_bounds_check(long index, long lb, long ub, long line) {
    if (index < lb || index > ub)
        __flang_bounds_fail(index, lb, ub, line);
}

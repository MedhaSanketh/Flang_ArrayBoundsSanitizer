#include <stdio.h>
#include <stdlib.h>

// Called before every descriptor-based array access.
// index = the index being accessed
// lb    = lower bound of the array
// ub    = upper bound of the array  
// line  = source line number (0 = not yet implemented)
void __flang_bounds_check(long index, long lb, long ub, long line) {
    if (index < lb || index > ub) {
        fprintf(stderr,
            "\n*** Fortran Array Bounds Violation ***\n"
            "  Index:       %ld\n"
            "  Valid range: [%ld : %ld]\n"
            "  Line:        %ld\n",
            index, lb, ub, line);
        abort();
    }
}

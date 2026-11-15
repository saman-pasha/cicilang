/* <functional.pl> (1.1.4; CCLLIB.md's phase 1b): C++'s function objects as the expressions a C program has -- the
   comparisons, the arithmetic, the bit and logical operators, negate and identity -- and a set ordered by two of them
   by name, `set<int, less>` and `set<int, greater>`. cicilang builds this file as C and cicilang++ as C++; functional.cpp
   is its twin over std::functional, which clang++ builds over libc++: the three print the same lines, functional.expect.
   `hash(x)` is the module's own value hash, and the rules of the module hold it; it is no std::hash, so no twin prints
   its value. */
#include <stdio.h>
#include <functional.pl>
#include <set.pl>
int main(void) {
    printf("compare: %d %d %d %d %d %d\n", less(1, 2), greater(1, 2), less_equal(2, 2), greater_equal(2, 2),
           equal_to(2, 2), not_equal_to(2, 2));
    printf("compare false: %d %d %d %d %d %d\n", less(2, 1), greater(2, 1), less_equal(1, 2), greater_equal(1, 2),
           equal_to(2, 3), not_equal_to(2, 2));
    printf("arith: %d %d %d %d %d %d\n", plus(2, 3), minus(2, 3), multiplies(2, 3), divides(7, 2), modulus(7, 2),
           negate(3));
    printf("float: %g %g %g %g\n", plus(1.5, 2.5), minus(5.5, 2.0), multiplies(1.5, 2.0), divides(5.0, 2.0));
    printf("logic: %d %d %d %d %d %d %d\n", logical_and(1, 0), logical_or(0, 2), logical_not(0), bit_and(6, 3),
           bit_or(6, 3), bit_xor(6, 3), bit_not(0));
    printf("identity: %d %g\n", identity(7), identity(2.5));
    set<int, less> a;
    insert(a, 3);
    insert(a, 1);
    insert(a, 2);
    printf("less:");
    for (size_t p = begin(a); p != end(a); p = next(a, p)) printf(" %d", key(a, p));
    printf("\n");
    set<int, greater> b;
    insert(b, 3);
    insert(b, 1);
    insert(b, 2);
    printf("greater:");
    for (size_t p = begin(b); p != end(b); p = next(b, p)) printf(" %d", key(b, p));
    printf("\n");
    return 0;
}

/* <any.pl> (1.1.5; CCLLIB.md's phase 1b): std::any for a C program -- an empty one, one born from an int, a double
   and a struct, any_cast of each, clone, swap, reset and has_value -- and a bitset's `any' called beside it, the name
   that C's grammar would read as a declaration of b: the reader infers b's type and calls the bitset's own function.
   cicilang builds this file as C and cicilang++ as C++; any.cpp is its twin over std::any and std::bitset, which clang++
   builds over libc++: the three print the same lines, any.expect. */
#include <stdio.h>
#include <any.pl>
#include <bitset.pl>
typedef struct point { int x, y; } point;
int main(void) {
    any<> a = 5;
    any<> b = 2.5;
    point pt = {1, 2};
    any<> c = pt;
    printf("values: %d %g %d %d\n", any_cast<int>(a), any_cast<double>(b), any_cast<point>(c).x, any_cast<point>(c).y);
    any<> d = clone(a);
    printf("clone: %d\n", any_cast<int>(d));
    swap(a, b);
    printf("swap: %g %d\n", any_cast<double>(a), any_cast<int>(b));
    reset(a);
    printf("reset: %d\n", has_value(a));
    bitset<8> bits = "10101010";
    printf("bitset: %d\n", any(bits));
    return 0;
}

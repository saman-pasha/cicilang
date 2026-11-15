/* THE RULES OF <any.pl> (1.1.5), checked from outside: a value born into an any is the value that any_cast gives back,
   for an int, a double, a char and a struct; clone gives the same value, a holder that is moved gives it whole, swap
   exchanges two, reset empties and has_value says whether a value is there. The walk of chance of 4000 steps makes an
   int any, casts it, clones it, casts the clone, empties both and repeats. cicilang builds this file as C and
   cicilang++ as C++; both print any_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <any.pl>
typedef struct point { int x, y; } point;
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(long long got, long long want, const char *what) { checks++; if (got != want) no(what); }
int main(void) {
    unsigned x = 2024;
    any<> a = 5;
    any<> b = 2.5;
    any<> c = (char)'q';
    point pt = {1, 2};
    any<> p = pt;
    is(any_cast<int>(a), 5, "an int is the int that was born");
    is((long long)(any_cast<double>(b) * 10.0), 25, "a double is the double that was born");
    is(any_cast<char>(c), 'q', "a char is the char that was born");
    is(any_cast<point>(p).x, 1, "a struct is the struct that was born");
    is(any_cast<point>(p).y, 2, "a struct's second member too");
    any<> d = clone(a);
    is(any_cast<int>(d), 5, "clone gives the same value");
    any<> e = a;
    is(any_cast<int>(e), 5, "a move gives the value whole");
    swap(b, c);
    is((long long)(any_cast<double>(c) * 10.0), 25, "swap gives the double to the other any");
    is(any_cast<char>(b), 'q', "swap gives the char to the other any");
    reset(d);
    is(has_value(d), 0, "reset empties");
    is(has_value(e), 1, "reset leaves another any full");
    for (int step = 0; step < 4000; step++) {
        x = x * 1103515245u + 12345u;
        int k = (int)(x >> 8 & 0xffff) - 32768;
        any<> n = k;
        is(any_cast<int>(n), k, "the walk's int is the value born");
        is(has_value(n), 1, "the walk's any is full");
        any<> m = clone(n);
        is(any_cast<int>(m), k, "the walk's clone is the value");
        reset(n);
        is(has_value(n), 0, "the walk's reset empties");
        is(any_cast<int>(m), k, "the walk's clone stays after the first is reset");
    }
    printf("the rules held at %ld checks, over a walk of chance of 4000 values\n", checks);
    return 0;
}

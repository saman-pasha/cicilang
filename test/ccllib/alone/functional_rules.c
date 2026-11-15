/* THE RULES OF <functional.pl> (1.1.4), checked from outside: every function object is the operator it names, over a
   walk of chance of 4000 steps on two integers -- less, greater, less_equal, greater_equal, equal_to, not_equal_to;
   plus, minus, multiplies, divides, modulus, negate; logical_and, logical_or, logical_not; bit_and, bit_or, bit_xor,
   bit_not; identity -- and a hash is one FNV-1a step of the value's bits, held to a model for int, char, short, long,
   unsigned, an enum and a pointer. Two sets ordered by the names `less' and `greater' hold 200 random keys each, walked
   in the order that their name gives. `hash(0)' is the known `(basis ^ 0) * prime' of FNV-1a's 32-bit constants, and the
   hash is the same for a value and for an enum's value. cicilang builds this file as C and cicilang++ as C++; both print
   functional_rules.expect. It has no twin */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <functional.pl>
#include <set.pl>
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(long long got, long long want, const char *what) { checks++; if (got != want) no(what); }
static unsigned long long model(unsigned long long x) { return (x ^ 2166136261ULL) * 16777619ULL; }
enum col { red, green };
int main(void) {
    unsigned x = 2024;
    int a = 3, b = 7;
    int *p = &a;
    enum col e = green;
    is(less(1, 2), 1 < 2, "less is <");
    is(greater(1, 2), 1 > 2, "greater is >");
    is(less_equal(2, 2), 2 <= 2, "less_equal is <=");
    is(greater_equal(2, 2), 2 >= 2, "greater_equal is >=");
    is(equal_to(3, 3), 3 == 3, "equal_to is ==");
    is(not_equal_to(3, 3), 3 != 3, "not_equal_to is !=");
    is(plus(2, 3), 2 + 3, "plus is +");
    is(minus(2, 3), 2 - 3, "minus is -");
    is(multiplies(2, 3), 2 * 3, "multiplies is *");
    is(divides(7, 2), 7 / 2, "divides is /");
    is(modulus(7, 2), 7 % 2, "modulus is %");
    is(negate(3), -3, "negate is unary -");
    is(logical_and(1, 0), 1 && 0, "logical_and is &&");
    is(logical_or(0, 2), 0 || 2, "logical_or is ||");
    is(logical_not(0), !0, "logical_not is !");
    is(bit_and(6, 3), 6 & 3, "bit_and is &");
    is(bit_or(6, 3), 6 | 3, "bit_or is |");
    is(bit_xor(6, 3), 6 ^ 3, "bit_xor is ^");
    is(bit_not(0), ~0, "bit_not is ~");
    is(identity(9), 9, "identity gives its argument");
    is((long long)hash(0), (long long)36342608889142559ULL, "hash(0) is the FNV-1a basis and prime");
    is((long long)hash(1), (long long)model(1), "hash(1) is the model");
    is((long long)hash(e), (long long)model((unsigned long long)green), "hash of an enum is the model of its value");
    is((long long)hash(p) == (long long)hash(p), 1, "hash of a pointer is the same for the same address");
    is((long long)hash((char)-3), (long long)model((unsigned long long)(char)-3), "hash of a char is the model");
    is((long long)hash((short)-3), (long long)model((unsigned long long)(short)-3), "hash of a short is the model");
    is((long long)hash((long)-3), (long long)model((unsigned long long)(long)-3), "hash of a long is the model");
    is((long long)hash((unsigned)3), (long long)model(3), "hash of an unsigned is the model");
    is((long long)hash(p) == (long long)model((unsigned long long)(uintptr_t)p), 1, "hash of a pointer is the model of its address");
    for (int step = 0; step < 4000; step++) {
        x = x * 1103515245u + 12345u;
        a = (int)(x >> 8 & 0xffff) - 32768;
        b = (int)(x >> 4 & 0xffff) - 32768;
        is(less(a, b), a < b, "less is < over the walk");
        is(greater(a, b), a > b, "greater is > over the walk");
        is(less_equal(a, b), a <= b, "less_equal is <= over the walk");
        is(greater_equal(a, b), a >= b, "greater_equal is >= over the walk");
        is(equal_to(a, b), a == b, "equal_to is == over the walk");
        is(not_equal_to(a, b), a != b, "not_equal_to is != over the walk");
        is(plus(a, b), a + b, "plus is + over the walk");
        is(minus(a, b), a - b, "minus is - over the walk");
        is(multiplies(a, b), a * b, "multiplies is * over the walk");
        if (b) is(divides(a, b), a / b, "divides is / over the walk");
        if (b) is(modulus(a, b), a % b, "modulus is % over the walk");
        is(negate(a), -a, "negate is unary - over the walk");
        is(logical_and(a, b), a && b, "logical_and is && over the walk");
        is(logical_or(a, b), a || b, "logical_or is || over the walk");
        is(logical_not(a), !a, "logical_not is ! over the walk");
        is(bit_and(a, b), a & b, "bit_and is & over the walk");
        is(bit_or(a, b), a | b, "bit_or is | over the walk");
        is(bit_xor(a, b), a ^ b, "bit_xor is ^ over the walk");
        is(bit_not(a), ~a, "bit_not is ~ over the walk");
        is(identity(a), a, "identity gives its argument over the walk");
        { unsigned long long h = hash(a); is((long long)h, (long long)model((unsigned long long)(long long)a), "hash is the model over the walk"); }
    }
    /* the names as a set's order: 200 keys, the walk says whether they come in the name's order */
    set<int, less> up;
    set<int, greater> down;
    for (int i = 0; i < 200; i++) {
        x = x * 1103515245u + 12345u;
        int k = (int)(x >> 8 & 0x3ff);
        insert(up, k);
        insert(down, k);
    }
    int prev = 0, first = 1;
    for (size_t q = begin(up); q != end(up); q = next(up, q)) {
        int k = key(up, q);
        if (!first) is(k > prev, 1, "set<int, less> walks in ascending order");
        prev = k; first = 0;
    }
    prev = 0; first = 1;
    for (size_t q = begin(down); q != end(down); q = next(down, q)) {
        int k = key(down, q);
        if (!first) is(k < prev, 1, "set<int, greater> walks in descending order");
        prev = k; first = 0;
    }
    printf("the rules held at %ld checks, over a walk of chance of 4000 steps and two sets of 200 keys\n", checks);
    return 0;
}

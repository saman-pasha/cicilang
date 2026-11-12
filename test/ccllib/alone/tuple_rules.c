/* THE RULES OF A TUPLE of <tuple.pl> (0.305), checked from outside over every case and not over a walk of chance: each
   tuple of three numbers of 0, 1 and 2 against each, each tuple of three of 0, 1 and a NaN against each, and each
   tuple of a pair and a number of 0 and 1 against each. EACH RELATION IS C++20'S, by the standard's words and not by
   the module's way to them ([tuple.rel]: `==' of each element; `<', `>', `<=' and `>=' by the synthesized three-way
   order of the elements, the first that is not equal deciding, where an unordered element, a NaN, ends it with no
   order, and all four are false). get<I> and get<T> are each element's place, swap exchanges every element, a copy
   keeps its own, and a tuple is born zero. cicilang builds this file as C and cicilang++ as C++; both print
   tuple_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <tuple.pl>
#include <pair.pl>
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(int got, int want, const char *what) { checks++; if (got != want) no(what); }
/* the three-way order of two numbers, C++20's for a double: -1, 0, 1, and 2 for unordered */
static int three(double x, double y) { return x < y ? -1 : y < x ? 1 : x == y ? 0 : 2; }
/* the synthesized three-way order of two rows of n numbers: the first that is not equal, or equal */
static int order(const double *x, const double *y, int n) {
    for (int i = 0; i < n; i++) {
        int t = three(x[i], y[i]);
        if (t != 0) return t;
    }
    return 0;
}
/* the six relations of two tuples, held to the order of their rows of numbers */
static void held(const double *x, const double *y, int n, int eq, int ne, int lt, int gt, int le, int ge) {
    int t = order(x, y, n), e = 1;
    for (int i = 0; i < n; i++) e = e && x[i] == y[i];
    is(eq, e, "== is == of each element");
    is(ne, !e, "!= is the negation of ==");
    is(lt, t == -1, "< is the order's less, where an unordered element ends the order");
    is(gt, t == 1, "> is the order's greater");
    is(le, t == -1 || t == 0, "<= is less or equal, false where an element is unordered");
    is(ge, t == 1 || t == 0, ">= is greater or equal, false where an element is unordered");
}
static void ints(void) {
    for (int a = 0; a < 27; a++)
        for (int b = 0; b < 27; b++) {
            tuple<int, int, int> p = {a / 9, a / 3 % 3, a % 3};
            tuple<int, int, int> q = {b / 9, b / 3 % 3, b % 3};
            double x[3] = {a / 9, a / 3 % 3, a % 3}, y[3] = {b / 9, b / 3 % 3, b % 3};
            is(get<0>(p), a / 9, "get<0> is the first element");
            is(get<1>(p), a / 3 % 3, "get<1> is the second element");
            is(get<2>(p), a % 3, "get<2> is the third element");
            held(x, y, 3, p == q, p != q, p < q, p > q, p <= q, p >= q);
        }
}
static void doubles(void) {
    volatile double zero = 0.0;
    double v[3];
    v[0] = 0.0;
    v[1] = 1.0;
    v[2] = zero / zero;
    for (int a = 0; a < 27; a++)
        for (int b = 0; b < 27; b++) {
            tuple<double, double, double> p = {v[a / 9], v[a / 3 % 3], v[a % 3]};
            tuple<double, double, double> q = {v[b / 9], v[b / 3 % 3], v[b % 3]};
            double x[3] = {v[a / 9], v[a / 3 % 3], v[a % 3]}, y[3] = {v[b / 9], v[b / 3 % 3], v[b % 3]};
            held(x, y, 3, p == q, p != q, p < q, p > q, p <= q, p >= q);
        }
}
static void nested(void) {
    for (int a = 0; a < 8; a++)
        for (int b = 0; b < 8; b++) {
            tuple<pair<int, int>, int> p = {{a >> 2 & 1, a >> 1 & 1}, a & 1};
            tuple<pair<int, int>, int> q = {{b >> 2 & 1, b >> 1 & 1}, b & 1};
            double x[3] = {a >> 2 & 1, a >> 1 & 1, a & 1}, y[3] = {b >> 2 & 1, b >> 1 & 1, b & 1};
            is(get<0>(p).second, a >> 1 & 1, "get<0> of a tuple of a pair is the pair");
            held(x, y, 3, p == q, p != q, p < q, p > q, p <= q, p >= q);
        }
}
static void places(void) {
    tuple<int, double, char> z;
    is(get<0>(z) == 0 && get<1>(z) == 0.0 && get<2>(z) == 0, 1, "a tuple is born zero");
    for (int i = 0; i < 64; i++) {
        tuple<int, double, char> t = {i, i / 2.0, (char)('a' + i % 26)};
        tuple<int, double, char> u = {-i, -i / 4.0, (char)('A' + i % 26)};
        get<int>(t) += 3;
        get<double>(t) *= 2;
        ++get<char>(t);
        is(get<0>(t), i + 3, "get<int> is the place of the int");
        is(get<1>(t) == i, 1, "get<double> is the place of the double");
        is(get<2>(t), 'a' + i % 26 + 1, "get<char> is the place of the char");
        int *p = &get<0>(u);
        *p = 7 * i;
        is(get<int>(u), 7 * i, "the address of get<0> is the int's");
        c := t;
        get<0>(c) = -1;
        is(get<0>(t), i + 3, "a copy is its own");
        swap(t, u);
        is(get<0>(t), 7 * i, "swap exchanges the first elements");
        is(get<1>(t) == -i / 4.0, 1, "swap exchanges the second elements");
        is(get<2>(t), 'A' + i % 26, "swap exchanges the third elements");
        is(get<0>(u), i + 3, "swap exchanges the first elements, the other way");
        is(get<2>(u), 'a' + i % 26 + 1, "swap exchanges the third elements, the other way");
    }
}
int main(void) {
    ints();
    doubles();
    nested();
    places();
    printf("the rules held at %ld checks, over every tuple of numbers, of NaNs and of a pair\n", checks);
    return 0;
}

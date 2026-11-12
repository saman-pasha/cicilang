/* THE RULES OF A PAIR of <pair.pl> (0.301), checked from outside over every case and not over a walk of chance: each
   pair of numbers from 0 to 3 against each, each pair of 0, 1 and a NaN against each, and each pair of pairs of 0 and
   1 against each. EACH RELATION IS C++20'S, by the standard's words and not by the module's way to them ([pairs.spec]:
   `==' of each member; `<', `>', `<=' and `>=' by the synthesized three-way order, the first members' and then the
   second's, where an unordered first member, a NaN, ends it with no order, and all four are false). `<=' and `>=' were
   the negations of `>' and `<' until 0.304, true over an unordered pair, and the cases of doubles held them so.
   A copy and swap leave each member as the model says. cicilang builds this file as C and cicilang++ as C++; both print
   pair_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <pair.pl>
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(int got, int want, const char *what) { checks++; if (got != want) no(what); }
/* the three-way order of two numbers, C++20's for a double: -1, 0, 1, and 2 for unordered */
static int three(double x, double y) { return x < y ? -1 : y < x ? 1 : x == y ? 0 : 2; }
static void ints(void) {
    for (int a = 0; a < 16; a++)
        for (int b = 0; b < 16; b++) {
            pair<int, int> p = {a / 4, a % 4};
            pair<int, int> q = {b / 4, b % 4};
            int t = three(p.first, q.first);
            if (t == 0) t = three(p.second, q.second);
            is(p == q, p.first == q.first && p.second == q.second, "== of two pairs is == of each member");
            is(p != q, !(p.first == q.first && p.second == q.second), "!= is the negation of ==");
            is(p < q, t == -1, "< is the three-way order of the members");
            is(p > q, t == 1, "> is the three-way order of the members");
            is(p <= q, t == -1 || t == 0, "<= of numbers is the three-way order");
            is(p >= q, t == 1 || t == 0, ">= of numbers is the three-way order");
            pair<int, int> r = p;
            pair<int, int> s = q;
            swap(r, s);
            is(r.first * 4 + r.second, b, "swap gives the first the second's members");
            is(s.first * 4 + s.second, a, "swap gives the second the first's members");
            r.first = 9;
            is(p.first, a / 4, "a copy is a pair of its own");
        }
}
static void doubles(void) {
    volatile double zero = 0.0;
    double v[3];
    v[0] = 0.0;
    v[1] = 1.0;
    v[2] = zero / zero;
    for (int a = 0; a < 9; a++)
        for (int b = 0; b < 9; b++) {
            pair<double, double> p = {v[a / 3], v[a % 3]};
            pair<double, double> q = {v[b / 3], v[b % 3]};
            int t = three(p.first, q.first);
            if (t == 0) t = three(p.second, q.second);
            is(p == q, p.first == q.first && p.second == q.second, "== with a NaN is == of each member");
            is(p != q, !(p.first == q.first && p.second == q.second), "!= with a NaN is the negation of ==");
            is(p < q, t == -1, "< with a NaN: an unordered member ends the order");
            is(p > q, t == 1, "> with a NaN: an unordered member ends the order");
            is(p <= q, t == -1 || t == 0, "<= with a NaN: an unordered member ends the order, and <= is false");
            is(p >= q, t == 1 || t == 0, ">= with a NaN: an unordered member ends the order, and >= is false");
        }
}
static void nested(void) {
    for (int a = 0; a < 8; a++)
        for (int b = 0; b < 8; b++) {
            pair<pair<int, int>, int> p = {{a >> 2 & 1, a >> 1 & 1}, a & 1};
            pair<pair<int, int>, int> q = {{b >> 2 & 1, b >> 1 & 1}, b & 1};
            is(p == q, a == b, "== of pairs of pairs is == of each member, the inner pair's own");
            is(p < q, a < b, "< of pairs of pairs is the order of the members, the inner pair's own");
            is(p > q, a > b, "> of pairs of pairs");
            is(p <= q, a <= b, "<= of pairs of pairs");
            is(p >= q, a >= b, ">= of pairs of pairs");
        }
}
int main(void) {
    ints();
    doubles();
    nested();
    printf("the rules held at %ld checks, over every pair of numbers, of NaNs and of pairs\n", checks);
    return 0;
}

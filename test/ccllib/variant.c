/* <variant.pl> (0.308; CCLLIB.md's phase 1b): the whole surface of ccllib's variant -- its birth, made of a value of
   each alternative's type, index, holds_alternative, get and get_if by an index and by a type, as values and as places,
   emplace, a copy, swap, valueless_by_exception, each relation over a NaN too, and visit by value, by a pointer and with
   a result -- over numbers, a character, a plain struct, monostate and a pair; a variant in a pair and in an optional
   beside it. cicilang builds this file as C and cicilang++ as C++; variant.cpp is its twin over std::variant, which
   clang++ builds over libc++: the three print the same lines, variant.expect. With a count, `variant 1000000', it
   sets, compares and visits the variants of an array of 64 that many times: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <variant.pl>
#include <pair.pl>
#include <optional.pl>
typedef struct point { int x, y; } point;
static void show_int(int x) { printf("int %d\n", x); }
static void show_double(double x) { printf("double %g\n", x); }
static void show_char(char x) { printf("char %c\n", x); }
static void show_point(const point *p) { printf("point %d %d\n", p->x, p->y); }
static void show_monostate(monostate m) { (void)m; printf("monostate\n"); }
static void show_pair_int_int(pair<int, int> p) { printf("pair %d %d\n", p.first, p.second); }
static int weight_int(int x) { return x; }
static int weight_double(double x) { return (int)(x * 10); }
static int weight_char(char x) { return x - 'a'; }
static void twice_int(int *x) { *x *= 2; }
static void twice_double(double *x) { *x *= 2; }
static void twice_char(char *x) { *x = (char)(*x + 1); }
static void say(const char *what, const variant<int, double, char> *v) {
    printf("%s: %zu ", what, index(*v));
    visit<show>(*v);
}
static void rel(const char *what, variant<int, double> a, variant<int, double> b) {
    printf("%s: %d %d %d %d %d %d\n", what, a == b, a != b, a < b, a > b, a <= b, a >= b);
}
static int many(long n) {
    variant<int, double, char> a[64];
    unsigned x = 12345;
    long less = 0, same = 0, s = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        unsigned k = (x >> 8) % 64, j = (x >> 16) % 64;
        switch (x >> 29 & 3) {
        case 0: a[k] = (int)(x >> 20 & 15); break;
        case 1: a[k] = (double)(x >> 22 & 7) / 2; break;
        default: a[k] = (char)('a' + (x >> 18 & 7)); break;
        }
        less += a[k] < a[j];
        same += a[k] == a[j];
        s += visit<weight>(a[j]);
    }
    printf("%ld %ld %ld\n", less, same, s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    variant<int, double, char> v;
    say("born", &v);
    v = 2.5;
    say("of a double", &v);
    v = 7;
    say("of an int", &v);
    v = (char)'q';
    say("of a char", &v);
    variant<int, double, char> w = 1.25;
    say("made of a double", &w);
    printf("holds: %d %d %d\n", holds_alternative<int>(w), holds_alternative<double>(w), holds_alternative<char>(w));
    get<1>(w) += 1;
    get<double>(w) *= 2;
    say("places", &w);
    double *pd = get_if<double>(&w);
    int *pi = get_if<0>(&w);
    printf("get_if: %d %g\n", pi != 0, pd ? *pd : -1.0);
    if (pd) *pd = 0.5;
    say("through get_if", &w);
    emplace<int>(w, 3) += 1;
    say("emplace", &w);
    emplace<2>(w, 'm');
    say("emplace a char", &w);
    u := w;
    get<char>(u) = 'n';
    say("the first", &w);
    say("its copy", &u);
    v = 5;
    w = 0.25;
    swap(v, w);
    say("swap v", &v);
    say("swap w", &w);
    printf("visit: %d %d %d\n", visit<weight>(v), visit<weight>(w), visit<weight>(u));
    visit<twice>(v);
    visit<twice>(w);
    visit<twice>(u);
    say("twice v", &v);
    say("twice w", &w);
    say("twice u", &u);
    printf("valueless: %d\n", valueless_by_exception(v));
    variant<int, double> a = 1, b = 2, c = 1.5, d = 0.5;
    rel("a a", a, a);
    rel("a b", a, b);
    rel("b a", b, a);
    rel("a c", a, c);
    rel("c a", c, a);
    rel("c d", c, d);
    volatile double zero = 0.0;
    variant<int, double> nan = zero / zero;
    rel("nan nan", nan, nan);
    rel("nan a", nan, a);
    rel("c nan", c, nan);
    variant<monostate, int> m;
    variant<monostate, int> m5 = 5;
    printf("monostate: %zu %d %d %d %d\n", index(m), m == m, m < m5, m5 <= m, m >= m);
    visit<show>(m);
    visit<show>(m5);
    point origin = {1, 2};
    variant<point, int> sp = origin;
    get<point>(sp).y = 3;
    visit<show>(sp);
    sp = 4;
    visit<show>(sp);
    pair<int, int> one = {1, 2};
    variant<pair<int, int>, int> vp = one;
    variant<pair<int, int>, int> vq = 9;
    get<0>(vp).second = 5;
    visit<show>(vp);
    printf("pair: %d %d %d\n", vp == vp, vp < vq, vq < vp);
    variant<int, char> vc = (char)'k';
    pair<variant<int, char>, int> pv = {vc, 3};
    printf("in a pair: %zu %c %d\n", index(pv.first), get<char>(pv.first), pv.second);
    optional<variant<int, double>> ov = c;
    oc := value(ov);
    printf("in an optional: %d %zu %g\n", has_value(ov), index(oc), get<1>(oc));
    return 0;
}

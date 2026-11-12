/* <span.pl> (0.295; CCLLIB.md's phase 1a): the whole surface of ccllib's span, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; span.cpp is its twin over std::span, which clang++ builds over libc++:
   the three print the same lines, span.expect. With a count, `span 1000000', it fills a vector with that many
   numbers and sums them by spans -- the halves, and windows of 64 --, and doubles a part of them through a span: the
   run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <vector.pl>
#include <array.pl>
#include <span.pl>
static long total(span<const int> s) {
    long t = 0;
    for (const int *p = begin(s); p != end(s); p++) t += *p;
    return t;
}
static void twice(span<int> s) {
    for (size_t i = 0; i < size(s); i++) s[i] *= 2;
}
static void show(const char *what, span<const int> s) {
    printf("%s=[", what);
    for (size_t i = 0; i < size(s); i++) printf(i ? " %d" : "%d", s[i]);
    printf("] %zu\n", size(s));
}
/* a span of the caller's array, returned: tied to it */
static span<int> middle(span<int> s) tie s { return subspan(s, 1, size(s) - 2); }
static int many(long n) {
    vector<int> v;
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push_back(v, (int)((x >> 8) % 1000));
    }
    span<int> w = v;
    twice(first(w, size(w) / 4));
    span<const int> s = v;
    long whole = total(s);
    long halves = total(first(s, size(s) / 2)) + total(last(s, size(s) - size(s) / 2));
    long windows = 0;
    for (size_t at = 0; at + 64 <= size(s); at += 64) windows += total(subspan(s, at, 64));
    printf("%ld %ld %ld %ld\n", whole, halves, windows, total(subspan(s, size(s) / 3)));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    /* made: of a C array, a pointer and a count, a vector, an array; const elements of a span, a vector, an array */
    int a[6] = {1, 2, 3, 4, 5, 6};
    vector<int> v = [10, 20, 30, 40];
    array<int, 3> r = [7, 8, 9];
    span<int> s = a;
    span<int> t = {a + 1, 3};
    span<int> sv = v;
    span<int> sr = r;
    span<const int> c = s;
    span<const int> cv = v;
    span<const int> cr = r;
    span<int> e;
    printf("%zu %zu %zu %zu %zu %d %d\n", size(s), size_bytes(t), size(sv), size(sr), size(e), empty(e), empty(s));
    printf("%d %d %d %d %d %d\n", s[0], at(s, 2), front(t), back(t), *data(sr), at(cv, 3));
    /* the elements written through a span, and read through another */
    s[0] = 100;
    twice(t);
    sv[3] = 41;
    sr[1] += 1;
    span<const int> ca = c;
    show("a", ca);
    show("v", cv);
    show("r", cr);
    int sum = 0;
    for (int *p = begin(sv); p != end(sv); p++) sum += *p;
    printf("%d %ld %ld\n", sum, total(cv), total(c));
    /* a part: the first, the last, from an offset, n from an offset */
    span<const int> f = first(c, 2);
    span<const int> l = last(c, 2);
    span<const int> o = subspan(c, 4);
    span<const int> m = subspan(c, 1, 3);
    span<const int> all = subspan(c, 0, dynamic_extent);
    span<const int> none = subspan(c, 6);
    show("first", f);
    show("last", l);
    show("off", o);
    show("mid", m);
    show("all", all);
    show("none", none);
    span<int> mid = middle(s);
    twice(mid);
    show("a", c);
    span<int> l3 = last(s, 3);
    span<int> one = first(l3, 1);
    one[0] = -1;
    show("a", c);
    return 0;
}

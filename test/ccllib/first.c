/* THE FIRST PROOF AFTER PHASE 0 (0.273; CCLLIB.md's Order): vector<int> with push, at, len and sort, dropped where its
   scope ends. cicilang builds this file as C and cicilang++ as C++; first.cpp is its twin over std::, which clang++
   builds over libc++: the three print the same lines, first.expect. With a count, `first 2000000', it sorts that many
   numbers and prints what it finds at seventeen places: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include "first.pl"
static long sum(vector<int> v) {
    long s = 0;
    for (size_t i = 0; i < len(v); i++) s += at(v, i);
    return s;
}
static int many(long n) {
    vector<int> v = [];
    unsigned x = 12345;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) { x = x * 1103515245u + 12345u; push(v, (int)(x >> 8)); }
    sort(v);
    long s = 0;
    for (size_t i = 0; i < len(v); i += 1 + len(v) / 16) s += at(v, i);
    printf("%zu %d %d %ld\n", len(v), at(v, 0), at(v, len(v) - 1), s);
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    vector<int> v = [int; 5, 3, 9];
    push(v, 1);
    push(v, 7);
    for (int i = 0; i < 20; i++) push(v, (i * 37 + 11) % 23);
    printf("%zu %d %d\n", len(v), at(v, 0), at(v, 4));
    sort(v);
    for (size_t i = 0; i < len(v); i++) printf("%d ", at(v, i));
    printf("\n");
    w := [double; 2.5, -1, 0.25];
    sort(w);
    printf("%g %g %g %zu\n", at(w, 0), at(w, 1), at(w, 2), len(w));
    printf("%ld\n", sum(v));
    return 0;
}

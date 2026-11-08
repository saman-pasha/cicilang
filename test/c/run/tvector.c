#include <stdio.h>
#include <stdlib.h>
#include "tvector.pl"
#include "tvhdr.h"
#include "tvhdr2.h"
typedef struct point { int x, y; } point_t;
static double sum(const vector<double> *v) {
    double s = 0;
    for (size_t i = 0; i < len(*v); i++) s += at(*v, i);
    return s;
}
int main(void) {
    vector<int> v;
    for (int i = 1; i <= 5; i++) push(v, i * i);
    vector<double> w = { 0, 0, NULL };
    push(w, 1.5);
    push(w, 2.25);
    vector<point_t> ps = { 0, 0, NULL };
    point_t p = { 3, 4 };
    push(ps, p);
    printf("%zu %d %zu %.2f %d\n", len(v), at(v, 4), len(w), sum(&w), at(ps, 0).y);
    inplace<double, 8> b = { 0 };
    b.a[b.len++] = 2.5;
    vector<int> *q = (vector<int> *)0;
    printf("%zu %zu %.1f %d %d\n", sizeof(vector<int>), sizeof(inplace<double, 8>), b.a[0], q == 0, ivec_sum(&v));
    printf("%.1f %d\n", max<double>(3, 2.5), max(4, 7));
    vector<long> lv = { 0, 0, NULL };
    push(lv, 30L);
    push(lv, 12L);
    printf("%ld %d\n", lsum(&lv), hcount);
    return 0;
}

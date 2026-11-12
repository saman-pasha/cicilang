// SHADOWED NAMES OVER INSTANCES (0.297): a name that a block declares again hides the outer one's states -- a
// parameter's `vector<int> *v' and the fields under it, an outer vector of the same name, a global one -- in a plain
// local declared and then given a value (the Ambitious session's finding 21), one given a value at its declaration, a
// pointer of the block on two roads, a for's declaration, a goto back inside the block and a pointer to another vector;
// the outer ones answer again after the block. Each was refused, `owner overwritten while live: v->data',
// `dropped_copied' or `use of a borrow after its owner was consumed', where clang builds the twin over std::vector
#include <stdio.h>
#include <vector.pl>
vector<int> g;
static double sum(vector<int> *v) {
    double r = 0;
    for (int i = 0; i < 2; i++) { double v; v = i; r += v; }
    return r + (double)len(*v);
}
static double sum_init(vector<int> *v) {
    double r = 0;
    for (int i = 0; i < 2; i++) { double v = 0; v = i; r += v; }
    return r + (double)len(*v);
}
static int after(vector<int> *v) {
    { double v; v = 2.5; (void)v; }
    push_back(*v, 9);
    return (int)len(*v);
}
static int pointer(vector<int> *v, int c) {
    int x = 4, y = 5, r = 0;
    for (int i = 0; i < 2; i++) {
        int *v;
        if (c + i) v = &x; else v = &y;
        r += *v;
    }
    return r + (int)len(*v);
}
static int loop(vector<int> *v) {
    int r = 0;
    for (int v = 0; v < 3; v++) r += v;
    return r + (int)len(*v);
}
static int jump(vector<int> *v) {
    int n = 0;
    {
        double v;
    again:
        v = n;
        n++;
        if (n < 3) goto again;
        (void)v;
    }
    return n + (int)len(*v);
}
static int other(vector<int> *v) {
    vector<int> w = [7, 8];
    int r = 0;
    { vector<int> *v = &w; push_back(*v, 9); r = (int)len(*v); }
    return r * 10 + (int)len(*v);
}
static int global(void) { int g = 3; g = g + 1; return g; }
int main(void) {
    vector<int> w = [1, 2, 3];
    double a = sum(&w);
    double b = sum_init(&w);
    int c = after(&w);
    int d = pointer(&w, 0);
    int e = loop(&w);
    int f = jump(&w);
    int h = other(&w);
    printf("%g %g %d %d %d %d %d\n", a, b, c, d, e, f, h);
    vector<int> v = [1, 2];
    { int v; v = 3; printf("%d ", v); }
    { vector<int> v = [4]; push_back(v, 5); printf("%zu ", len(v)); }
    push_back(g, 5);
    printf("%zu %d %zu\n", len(v), global(), len(g));
    vector_int_drop(&g);
    return 0;
}

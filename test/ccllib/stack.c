/* <stack.pl> (0.280; CCLLIB.md's phase 1a): the whole surface of ccllib's stack, each function once at least. cicilang
   builds this file as C and cicilang++ as C++; stack.cpp is its twin over std::stack, which clang++ builds over
   libc++: the three print the same lines, stack.expect. With a count, `stack 30000000', it pushes that many numbers
   and pops two of each three on the way, then empties the stack: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <stack.pl>
typedef struct point { int x, y; } point;
static long total(stack<int> s) {
    long t = 0;
    while (!empty(s)) t += pop(s);
    return t;
}
static int many(long n) {
    stack<int> s;
    unsigned x = 12345;
    long t = 0;
    size_t high = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push(s, (int)((x >> 8) % 1000));
        if (size(s) > high) high = size(s);
        if (i % 3 != 0) t += pop(s) + (empty(s) ? 0 : top(s));
    }
    size_t left = size(s);
    c := clone(s);
    printf("%zu %zu %ld %d %ld\n", left, high, t, s == c, total(c));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    stack<int> s;
    printf("%d %zu\n", empty(s), size(s));
    for (int i = 0; i < 10; i++) push(s, i * i);
    emplace(s, 7);
    printf("%zu %zu %d %d\n", size(s), len(s), top(s), empty(s));
    int a = pop(s);
    int b = pop(s);
    printf("%d %d %d %zu\n", a, b, top(s), size(s));
    stack<int> t = [1, 2, 3];
    u := clone(t);
    push(u, 4);
    printf("%d %d %d %d %d %d\n", t == u, t != u, t < u, t > u, t <= u, t >= u);
    swap(t, u);
    int more[2] = {8, 9};
    push_range(t, more, 2);
    printf("%d %zu %d %zu\n", top(t), size(t), top(u), size(u));
    while (!empty(t)) printf("%d ", pop(t));
    printf("| %zu\n", size(t));
    stack<double> f = [2.5, -1, 0.25];
    push(f, 4);
    printf("%g %zu\n", top(f), size(f));
    stack<point> ps;
    push(ps, (point){1, 2});
    push(ps, (point){3, 4});
    printf("%d %d %zu\n", top(ps).x, top(ps).y, size(ps));
    point p = pop(ps);
    printf("%d %d %d\n", p.x, top(ps).y, (int)size(ps));
    printf("%ld\n", total(s));
    return 0;
}

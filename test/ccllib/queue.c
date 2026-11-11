/* <queue.pl> (0.280; CCLLIB.md's phase 1a): the whole surface of ccllib's queue and priority_queue, each function
   once at least. cicilang builds this file as C and cicilang++ as C++; queue.cpp is its twin over std::queue and
   std::priority_queue, which clang++ builds over libc++: the three print the same lines, queue.expect. With a count,
   `queue 3000000', it sends that many numbers through a queue, then through a priority_queue that gives the
   greatest first and through one that gives the least first: the run that the costs time */
#include <stdio.h>
#include <stdlib.h>
#include <queue.pl>
typedef struct job { int rank, id; } job;
static int later(int a, int b) { return a > b; }
static int lower_rank(job a, job b) { return a.rank < b.rank; }
static long total(queue<int> q) {
    long t = 0;
    while (!empty(q)) t += pop(q);
    return t;
}
static int many(long n) {
    queue<int> q;
    priority_queue<int> h;
    priority_queue<int, later> m;
    unsigned x = 12345;
    long t = 0, u = 0, w = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push(q, (int)((x >> 8) % 1000));
        if (i % 4 != 0) t += pop(q) + (empty(q) ? 0 : front(q)) + back(q) % 3;
    }
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        push(h, (int)((x >> 8) % 1000000));
        push(m, (int)((x >> 8) % 1000000));
        if (i % 3 == 0) { u += pop(h); w += pop(m); }
    }
    for (long i = 0; !empty(h); i++) { u += pop(h) % 7 * (i % 5); w += pop(m) % 7 * (i % 5); }
    printf("%zu %ld %ld %ld %ld\n", size(q), t, u, w, total(q));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(atol(argv[1]));
    queue<int> q;
    printf("%d %zu\n", empty(q), size(q));
    for (int i = 0; i < 20; i++) { push(q, i * 3); if (i % 3 == 2) printf("%d ", pop(q)); }
    emplace(q, 7);
    printf("| %zu %zu %d %d %d\n", size(q), len(q), front(q), back(q), empty(q));
    queue<int> r = [1, 2, 3];
    c := clone(r);
    push(c, 4);
    printf("%d %d %d %d %d %d\n", r == c, r != c, r < c, r > c, r <= c, r >= c);
    swap(r, c);
    int more[2] = {8, 9};
    push_range(r, more, 2);
    printf("%d %d %zu %d %zu\n", front(r), back(r), size(r), back(c), size(c));
    while (!empty(r)) printf("%d ", pop(r));
    printf("| %zu\n", size(r));
    priority_queue<int> h;
    printf("%d %zu\n", empty(h), size(h));
    unsigned x = 7;
    for (int i = 0; i < 12; i++) { x = x * 1103515245u + 12345u; push(h, (int)((x >> 8) % 100)); }
    emplace(h, 50);
    push_range(h, more, 2);
    g := clone(h);
    printf("%zu %zu %d:", size(h), len(h), top(h));
    while (!empty(h)) printf(" %d", pop(h));
    printf(" | %zu %d\n", size(g), top(g));
    priority_queue<int, later> m = [5, 3, 9, 1];
    push(m, 4);
    priority_queue<int, later> k;
    push(k, 100);
    swap(m, k);
    printf("%zu %d %zu %d:", size(m), top(m), size(k), top(k));
    while (!empty(k)) printf(" %d", pop(k));
    printf("\n");
    priority_queue<job, lower_rank> jobs;
    push(jobs, (job){2, 10});
    push(jobs, (job){7, 11});
    push(jobs, (job){5, 12});
    job first = pop(jobs);
    printf("%d %d %d %zu\n", first.rank, first.id, top(jobs).id, size(jobs));
    queue<double> f = [2.5, -1];
    push(f, 4);
    printf("%g %g %zu\n", front(f), back(f), size(f));
    printf("%ld\n", total(q));
    return 0;
}

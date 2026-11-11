// the twin of queue.c over std::queue and std::priority_queue (0.280): clang++ builds it over libc++, and what it
// prints is queue.expect
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <queue>
#include <utility>
#include <vector>
struct job { int rank, id; };
struct lower_rank { bool operator()(const job &a, const job &b) const { return a.rank < b.rank; } };
static long total(std::queue<int> q) {
    long t = 0;
    while (!q.empty()) { t += q.front(); q.pop(); }
    return t;
}
static int many(long n) {
    std::queue<int> q;
    std::priority_queue<int> h;
    std::priority_queue<int, std::vector<int>, std::greater<int>> m;
    unsigned x = 12345;
    long t = 0, u = 0, w = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        q.push((int)((x >> 8) % 1000));
        if (i % 4 != 0) { int v = q.front(); q.pop(); t += v + (q.empty() ? 0 : q.front()) + q.back() % 3; }
    }
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        h.push((int)((x >> 8) % 1000000));
        m.push((int)((x >> 8) % 1000000));
        if (i % 3 == 0) { u += h.top(); h.pop(); w += m.top(); m.pop(); }
    }
    for (long i = 0; !h.empty(); i++) { u += h.top() % 7 * (i % 5); h.pop(); w += m.top() % 7 * (i % 5); m.pop(); }
    size_t left = q.size();
    std::printf("%zu %ld %ld %ld %ld\n", left, t, u, w, total(std::move(q)));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::queue<int> q;
    std::printf("%d %zu\n", q.empty(), q.size());
    for (int i = 0; i < 20; i++) { q.push(i * 3); if (i % 3 == 2) { std::printf("%d ", q.front()); q.pop(); } }
    q.emplace(7);
    std::printf("| %zu %zu %d %d %d\n", q.size(), q.size(), q.front(), q.back(), q.empty());
    std::queue<int> r;
    r.push(1); r.push(2); r.push(3);
    std::queue<int> c = r;
    c.push(4);
    std::printf("%d %d %d %d %d %d\n", r == c, r != c, r < c, r > c, r <= c, r >= c);
    std::swap(r, c);
    int more[2] = {8, 9};
    for (int v : more) r.push(v);
    std::printf("%d %d %zu %d %zu\n", r.front(), r.back(), r.size(), c.back(), c.size());
    while (!r.empty()) { std::printf("%d ", r.front()); r.pop(); }
    std::printf("| %zu\n", r.size());
    std::priority_queue<int> h;
    std::printf("%d %zu\n", h.empty(), h.size());
    unsigned x = 7;
    for (int i = 0; i < 12; i++) { x = x * 1103515245u + 12345u; h.push((int)((x >> 8) % 100)); }
    h.emplace(50);
    for (int v : more) h.push(v);
    std::priority_queue<int> g = h;
    std::printf("%zu %zu %d:", h.size(), h.size(), h.top());
    while (!h.empty()) { std::printf(" %d", h.top()); h.pop(); }
    std::printf(" | %zu %d\n", g.size(), g.top());
    std::priority_queue<int, std::vector<int>, std::greater<int>> m;
    for (int v : {5, 3, 9, 1}) m.push(v);
    m.push(4);
    std::priority_queue<int, std::vector<int>, std::greater<int>> k;
    k.push(100);
    std::swap(m, k);
    std::printf("%zu %d %zu %d:", m.size(), m.top(), k.size(), k.top());
    while (!k.empty()) { std::printf(" %d", k.top()); k.pop(); }
    std::printf("\n");
    std::priority_queue<job, std::vector<job>, lower_rank> jobs;
    jobs.push(job{2, 10});
    jobs.push(job{7, 11});
    jobs.push(job{5, 12});
    job first = jobs.top(); jobs.pop();
    std::printf("%d %d %d %zu\n", first.rank, first.id, jobs.top().id, jobs.size());
    std::queue<double> f;
    f.push(2.5); f.push(-1);
    f.push(4);
    std::printf("%g %g %zu\n", f.front(), f.back(), f.size());
    std::printf("%ld\n", total(std::move(q)));
    return 0;
}

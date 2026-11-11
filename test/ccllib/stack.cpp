// the twin of stack.c over std::stack (0.280): clang++ builds it over libc++, and what it prints is stack.expect
#include <cstdio>
#include <cstdlib>
#include <stack>
#include <utility>
struct point { int x, y; };
static long total(std::stack<int> s) {
    long t = 0;
    while (!s.empty()) { t += s.top(); s.pop(); }
    return t;
}
static int many(long n) {
    std::stack<int> s;
    unsigned x = 12345;
    long t = 0;
    size_t high = 0;
    if (n < 1) n = 1;
    for (long i = 0; i < n; i++) {
        x = x * 1103515245u + 12345u;
        s.push((int)((x >> 8) % 1000));
        if (s.size() > high) high = s.size();
        if (i % 3 != 0) { int v = s.top(); s.pop(); t += v + (s.empty() ? 0 : s.top()); }
    }
    size_t left = s.size();
    std::stack<int> c = s;
    std::printf("%zu %zu %ld %d %ld\n", left, high, t, s == c, total(std::move(c)));
    return 0;
}
int main(int argc, char **argv) {
    if (argc > 1) return many(std::atol(argv[1]));
    std::stack<int> s;
    std::printf("%d %zu\n", s.empty(), s.size());
    for (int i = 0; i < 10; i++) s.push(i * i);
    s.emplace(7);
    std::printf("%zu %zu %d %d\n", s.size(), s.size(), s.top(), s.empty());
    int a = s.top(); s.pop();
    int b = s.top(); s.pop();
    std::printf("%d %d %d %zu\n", a, b, s.top(), s.size());
    std::stack<int> t;
    t.push(1); t.push(2); t.push(3);
    std::stack<int> u = t;
    u.push(4);
    std::printf("%d %d %d %d %d %d\n", t == u, t != u, t < u, t > u, t <= u, t >= u);
    std::swap(t, u);
    int more[2] = {8, 9};
    for (int m : more) t.push(m);
    std::printf("%d %zu %d %zu\n", t.top(), t.size(), u.top(), u.size());
    while (!t.empty()) { std::printf("%d ", t.top()); t.pop(); }
    std::printf("| %zu\n", t.size());
    std::stack<double> f;
    f.push(2.5); f.push(-1); f.push(0.25);
    f.push(4);
    std::printf("%g %zu\n", f.top(), f.size());
    std::stack<point> ps;
    ps.push(point{1, 2});
    ps.push(point{3, 4});
    std::printf("%d %d %zu\n", ps.top().x, ps.top().y, ps.size());
    point p = ps.top(); ps.pop();
    std::printf("%d %d %d\n", p.x, ps.top().y, (int)ps.size());
    std::printf("%ld\n", total(std::move(s)));
    return 0;
}

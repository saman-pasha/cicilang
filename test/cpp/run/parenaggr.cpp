// C++20's parenthesized aggregate initialization ([dcl.init.general]/16.6.2.2, P0960)
#include <cstdio>
#include <vector>
#include <memory>
struct P { int x; int y; };
struct Q { int a; P p; double d = 2.5; };
struct R { int k[2]; long m; };
int main() {
    P p(1, 2);
    Q q(3, P(4, 5));
    Q q2(6);
    auto *h = new P(7, 8);
    int arr[](9, 10, 11);
    std::printf("%d %d %d %d %d %.1f %d %d %.1f %d %d %d %zu\n", p.x, p.y, q.a, q.p.x, q.p.y, q.d, q2.a, q2.p.x, q2.d, h->x, h->y, arr[2], sizeof arr / sizeof arr[0]);
    delete h;
    std::vector<P> v; v.emplace_back(12, 13); v.emplace_back(14);
    std::printf("%d %d %d %d\n", v[0].x, v[0].y, v[1].x, v[1].y);
    auto u = std::make_unique<P>(15, 16);
    std::printf("%d %d\n", u->x, u->y);
    P t = P(17, 18); R r(R{{1, 2}, 3});
    std::printf("%d %d %d %ld\n", t.x, t.y, r.k[1], r.m);
}

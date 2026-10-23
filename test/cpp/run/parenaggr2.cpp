// C++20's parenthesized aggregate initialization beyond a local: a global, a static local, members of aggregate classes, a base, a string member, std::vector::emplace_back, std::optional and std::make_shared over a plain struct, a copy, narrowing, an array of strings, is_constructible
#include <cstdio>
#include <memory>
#include <optional>
#include <string>
#include <type_traits>
#include <vector>
struct P { int x; int y; };
struct Q { int a; P p; double d = 2.5; };
struct D : P { int z; };
struct W { std::string s; int k; };
struct H { Q q; P p; H() : q(3, P(4, 5)), p(6) {} };
P gp(1, 2);
Q gq(7);
int main() {
    static Q sq(8, P(9, 10));
    std::printf("%d %d %d %.1f %d %d %d\n", gp.x, gp.y, gq.a, gq.d, sq.a, sq.p.x, sq.p.y);
    H h; std::printf("%d %d %d %d %d\n", h.q.a, h.q.p.x, h.q.p.y, h.p.x, h.p.y);
    D d(P(11, 12), 13); std::printf("%d %d %d\n", d.x, d.y, d.z);
    W w("ab", 3); std::printf("%s %d\n", w.s.c_str(), w.k);
    std::vector<W> v; v.emplace_back("cd", 4); v.emplace_back("ef"); std::printf("%s %d %s %d\n", v[0].s.c_str(), v[0].k, v[1].s.c_str(), v[1].k);
    std::optional<P> o(std::in_place, 14, 15); std::printf("%d %d\n", o->x, o->y);
    auto sp = std::make_shared<P>(16, 17); std::printf("%d %d\n", sp->x, sp->y);
    P p2(gp); Q q3(gq); std::printf("%d %d %d %.1f\n", p2.x, p2.y, q3.a, q3.d);
    P pn(1.5, 2.7); std::printf("%d %d\n", pn.x, pn.y);
    std::string a[]("x", "yz"); std::printf("%s %s %zu\n", a[0].c_str(), a[1].c_str(), sizeof a / sizeof a[0]);
    std::printf("%d %d %d %d\n", (int) std::is_constructible_v<D, P, int>, (int) std::is_constructible_v<W, const char *, int>, (int) std::is_constructible_v<P, int, int, int>, (int) std::is_constructible_v<Q, Q>);
}

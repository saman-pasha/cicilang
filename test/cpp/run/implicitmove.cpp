// C++20's implicit moves (P1825) and C++23's simpler one (P2266): a returned rvalue reference, a base from a derived
#include <cstdio>
struct M { int k = 0; M() {} M(const M &) { std::puts("copy"); } M(M &&) { std::puts("move"); } };
struct D : M {};
M f(M &&r) { return r; }
M g(M m) { return m; }
M h() { D d; return d; }
struct Box { M m; Box(M x) : m(static_cast<M &&>(x)) {} };
Box b() { M m; return m; }
void th(M m) { try { throw m; } catch (M &c) { std::puts("caught"); } }
int main() {
    M a; std::puts("f"); M x = f(static_cast<M &&>(a));
    std::puts("g"); M y = g(M());
    std::puts("h"); M z = h();
    std::puts("b"); Box bx = b();
    std::puts("th"); th(M());
}

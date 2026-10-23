#include <cstdio>
struct S { int v; S(int x) : v(x) { std::printf("ctor %d\n", x); } S(const S &o) : v(o.v) { std::printf("copy %d\n", v); } S &operator=(S o) { std::printf("assign %d\n", o.v); v = o.v; return *this; } };
S g(3);
S &left() { static S s(1); std::printf("left\n"); return s; }
S right() { std::printf("right\n"); return S(2); }
S &lref() { std::printf("lref\n"); return g; }
int main() { left() = right(); std::printf("--\n"); left() = lref(); std::printf("%d\n", left().v); }

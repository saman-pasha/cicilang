// NRVO: a named local returned is built in the caller's object where clang builds it so ([class.copy.elision]/1.1)
#include <cstdio>
struct S {
  int v;
  S(int x) : v(x) { std::printf("ctor %d\n", v); }
  S(const S &o) : v(o.v) { std::printf("copy %d\n", v); }
  S(S &&o) : v(o.v) { std::printf("move %d\n", v); }
  ~S() { std::printf("dtor %d\n", v); }
};
S make() { S s(3); s.v = 4; return s; }
S make2(bool c) { S a(1), b(2); if (c) return a; return b; }
S make3(int n) { S s(n); if (n > 5) return s; s.v = n * 2; return s; }
int main() {
  S x = make();
  std::printf("x %d\n", x.v);
  S y = make2(true);
  std::printf("y %d\n", y.v);
  S z = make3(3);
  std::printf("z %d\n", z.v);
}

// the deduced result of a plain function by lvalue reference (0.117, C++14 [dcl.spec.auto]): `auto &f() { return g; }' is `int &' and `const auto &' keeps its
// const -- it was `not lowered yet: auto' at the first call. A call returning a reference to an ARRAY decays like the array does (libc++'s charconv
// `static auto &__pow() { return __table<>::__pow10_32; }' is added to), where the lowering loaded the whole array
#include <cstdio>
int g = 5;
auto &gr() { return g; }
const int cg = 9;
const auto &cgr() { return cg; }
static const unsigned tbl[5] = {1, 10, 100, 1000, 10000};
auto &table() { return tbl; }
const unsigned (&table2())[5] { return tbl; }
int sum(const unsigned *p, int n) { int s = 0; for (int i = 0; i < n; i++) s += (int)p[i]; return s; }
int main() {
  gr() += 2;
  gr()++;
  std::printf("%d %d\n", g, gr() + cgr());
  std::printf("%d %d %d\n", sum(table() + 1, 3), sum(table2() + 2, 2), sum(table(), 5));
  std::printf("%u %u %d\n", table()[3], *(table2() + 4), (int)sizeof(table()));
  return 0;
}

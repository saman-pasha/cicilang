// AN ARRAY'S PRVALUE BY ITS TYPE'S NAME (1.6.56; [expr.type.conv]/2, [dcl.init.list]/3.4): `A3{1, 2, 3}' over `using A3 = int[3]' is
// a compound literal of the array, its elements from the items and the rest zero, `int[]''s bound the items' count; a reference binds
// its storage. It was `not lowered yet: phase(desugaring)', and a reference to it, once made, read its temporary's bytes
#include <cstdio>
using A3 = int[3];
using A = int[];
typedef int A2[2];
struct P { int a, b; };
using PA = P[2];
int sum(const int (&a)[3]) { return a[0] + a[1] + a[2]; }
int main() {
  int s = 0;
  for (int v : A3{1, 2, 3}) s += v;
  auto &&r = A3{4, 5, 6};
  const A2 &q = A2{7, 8};
  auto &&z = A3{};
  int n = 0;
  for (int v : A3{9}) n += v;
  int m = 0;
  for (const P &p : PA{{1, 2}, {3, 4}}) m += p.a * p.b;
  std::printf("%d %d %d %d %d %d %d\n", s, r[1], q[0] + q[1], z[0] + z[2], n, m, sum(A3{1, 2, 4}));
  std::printf("%d %d %d\n", (int)sizeof(A3{1, 2}), (int)sizeof(A{1, 2, 3}), sum(A{3, 3, 3}));
  return 0;
}

// BRACE ELISION OF A SCALAR ITEM IN C++ (0.164): `std::array<T, 1>' is the struct `{ T __elems_[1]; }' -- one item,
// one member, and the item is the element; a global, a constexpr one, a local, a member's default, an aggregate's
// array member followed by another member
#include <array>
#include <cstdio>
std::array<int, 1> g = {5};
constexpr std::array<unsigned char, 1> h = {3};
struct Q { int a[2]; int b; };
Q gq = {1, 2};
struct H { std::array<long, 1> v = {9}; int k = 4; };
int main() {
  std::array<int, 1> l = {6};
  Q q = {7, 8};
  H x;
  std::printf("%d %d %d %d %d | %d | %d %d %d | %ld %d\n", g[0], h[0], gq.a[0], gq.a[1], gq.b, l[0], q.a[0], q.a[1], q.b, x.v[0], x.k);
  return 0;
}

// argument-dependent lookup of a keyed name asks the argument's bases (0.221; [basic.lookup.argdep]/3.2): `count(d)' over a
// `D : ns::B' and over a `const E *' of `E : D' finds the program's `ns::count', which the program's namespace keyed apart from
// <algorithm>'s std::count -- and a class derived from a namespace's plain struct is a class (`struct D : ns::B { };')
#include <algorithm>
#include <cstdio>
#include <vector>
namespace ns {
struct B { int v; };
int count(const B &b) { return b.v + 10; }
int count(const B *b) { return b->v + 20; }
}
struct D : ns::B { };
struct E : D { };
int main() {
  D d{{5}};
  E e{};
  e.v = 7;
  std::vector<int> w{1, 2, 1};
  std::printf("%d %d %d\n", count(d), count(&e), (int) std::count(w.begin(), w.end(), 1));
}

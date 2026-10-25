// A type that decltype gives carries no object's alignment ([dcl.align]/1; 0.206): alignof(decltype(x)) of an aligned
// variable, a static member, a member through an object and through its class; decltype of a member of a const object,
// unparenthesized and parenthesized.
#include <cstdio>
#include <type_traits>

alignas(64) int g = 1;
struct S { alignas(32) int m; static int sm; };
alignas(16) int S::sm = 2;

template <class T> int al() { return int(alignof(T)); }

int main() {
  alignas(32) int x = 3;
  alignas(16) static double sd = 4.0;
  std::printf("%d %d %d %d\n", int(alignof(decltype(x))), int(alignof(decltype(g))), int(alignof(decltype(sd))), int(alignof(decltype(S::sm))));
  std::printf("%d %d %d\n", al<decltype(x)>(), int(sizeof(decltype(x))), int(std::is_same_v<decltype(x), int>));
  auto y = x;
  decltype(x) z = 5;
  std::printf("%d %d %d\n", int(alignof(decltype(y))), int(alignof(decltype(z))), y + z);
  S s{7};
  std::printf("%d %d %d\n", int(alignof(decltype(s.m))), int(alignof(S)), int(alignof(decltype(S::m))));
  const S cs{8};
  const S *cp = &cs;
  std::printf("%d %d %d %d\n", int(std::is_same_v<decltype(cs.m), int>), int(std::is_same_v<decltype(cp->m), int>),
              int(std::is_same_v<decltype((cs.m)), const int &>), int(std::is_same_v<decltype(S::m), int>));
}

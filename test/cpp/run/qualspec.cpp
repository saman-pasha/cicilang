// A specialization declared by a namespace-qualified name -- `template <class C> struct fm::cont<str<C>>', a
// variable template's `fm::ins<str<C>>' -- belongs to the namespace it names ([namespace.memdef]/2).
#include <cstdio>
template <class C, class T = int> struct str { C c; };
namespace fm {
template <class X> inline constexpr bool ins = false;
template <class X> struct cont { static constexpr int k = 0; };
template <class X> concept insertable = ins<X>;
}
template <class C> inline constexpr bool fm::ins<str<C>> = true;
template <class C> struct fm::cont<str<C>> { static constexpr int k = 1; };
int main() {
  std::printf("%d %d %d %d\n", fm::ins<str<char>>, fm::ins<int>, fm::cont<str<int>>::k, fm::insertable<str<char>>);
  return 0;
}

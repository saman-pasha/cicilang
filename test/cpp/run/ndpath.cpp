// A qualified name whose nested-name-specifier names a parameter anywhere -- inside a template-id segment
// included -- is a non-deduced context ([temp.deduct.type]/5.1): matched once the others bind it.
#include <cstdio>
template <class C> requires (sizeof(C) == 1) struct rb { struct iterator { C *p; }; };
template <class It, class C> struct ctx { static constexpr int k = 1; };
template <class C> struct ctx<typename rb<C>::iterator, C> { static constexpr int k = 2; };
int main() {
  std::printf("%d %d %d\n", ctx<char *, char>::k, ctx<rb<char>::iterator, char>::k, ctx<int *, int>::k);
  return 0;
}

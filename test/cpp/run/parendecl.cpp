// A QUALIFIED TYPE BEFORE A PARENTHESIZED DECLARATOR, in a block (0.161; [stmt.ambig]: what can be a declaration is one):
// `ns::T (*m)(int) = &ns::make;' declares a pointer to function, where the reader read the call of a functional cast;
// and `auto' initialized by a name the table holds as a function is the desugaring's to deduce: `auto b =
// std::ranges::begin;' is libc++'s object, where the flattened `begin' made it a pointer to a function; and `T{k}' of a
// plain struct named through a typedef is its aggregate, where it was a cast of k to the struct that LLVM refused
#include <cstdio>
#include <ranges>
#include <vector>
namespace ns {
struct S { int v; };
typedef S T;
int twice(T s) { return 2 * s.v; }
T make(int k) { return T{k}; }
}
int main() {
  int (*a)(ns::T) = &ns::twice;
  ns::T (*m)(int) = &ns::make;
  ns::S (&mr)(int) = ns::make;
  std::vector<int> v{7, 1, 2};
  auto b = std::ranges::begin;
  auto e = std::ranges::end;
  std::printf("%d %d %d %d %d\n", a(ns::T{4}), m(5).v, mr(6).v, *b(v), (int) (e(v) - b(v)));
  return 0;
}

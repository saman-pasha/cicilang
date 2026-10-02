// std::is_abstract answers by the ONE test an abstract class has (cpp_abstract_class): a slot nothing implements,
// or one whose implementation is the pure declaration itself ([class.abstract]).
#include <cstdio>
#include <type_traits>
struct A { virtual void f() = 0; };
struct B : A { void f() override {} };
struct C { int x; };
int main() {
  std::printf("%d %d %d\n", std::is_abstract_v<A>, std::is_abstract_v<B>, std::is_abstract_v<C>);
  return 0;
}

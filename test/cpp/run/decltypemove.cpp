// decltype(*p) is a reference to the pointee, and decltype(std::move(x)) an rvalue reference ([dcl.type.decltype]),
// through an alias template over declval<I&>() and with I itself a reference type, collapsed
#include <type_traits>
#include <utility>
#include <cstdio>
struct C { int v; };
template <class I> using deref_t = decltype(*std::declval<I&>());
template <class I> using move_t = decltype(std::move(*std::declval<I&>()));
int main() {
  std::printf("%d %d %d %d\n", (int) std::is_reference<deref_t<int *&>>::value, (int) std::is_reference<deref_t<int *>>::value,
              (int) std::is_same<deref_t<C *&>, C &>::value, (int) std::is_same<move_t<C *&>, C &&>::value);
  C c{1}; C *p = &c;
  std::printf("%d %d %d %d\n", (int) std::is_rvalue_reference<move_t<C *&>>::value, (int) std::is_same<decltype(std::move(*p)), C &&>::value,
              (int) std::is_same<move_t<C *>, C &&>::value, (int) std::is_same<std::remove_reference_t<move_t<C *>>, C>::value);
  return 0;
}

// A CRTP base that requires `std::is_class_v' of its derived class, and a template-id parameter that deduces through a LATER EMPTY base. libc++ 21's range adaptor
// closures are written so: `struct __fn : __range_adaptor_closure<__fn>' (a plain class of a header, being loaded when its base is instantiated), and
// `__pipeable<_Fn> : _Fn, __range_adaptor_closure<__pipeable<_Fn>>' asked through `__derived_from_range_adaptor_closure(__range_adaptor_closure<_Tp> *)'.
#include <concepts>
#include <cstdio>
#include <type_traits>
template <class T> requires std::is_class_v<T> && std::same_as<T, std::remove_cv_t<T>> struct Closure {};
struct Plus { int operator()(int x) const { return x + 1; } };
struct Twice : Closure<Twice> { int operator()(int x) const { return x * 2; } };
template <class Fn> struct Piped : Fn, Closure<Piped<Fn>> { explicit Piped(Fn f) : Fn(f) {} };
template <class T> T derive_from(Closure<T> *);
template <class T> concept is_closure = requires { { derive_from((std::remove_cvref_t<T> *) nullptr) } -> std::same_as<std::remove_cvref_t<T>>; };
int main() {
  Twice t;
  Piped<Plus> p{Plus{}};
  using P = Piped<Plus>;
  std::printf("%d %d\n", t(4), p(4));
  std::printf("%d %d\n", (int) std::is_same_v<decltype(derive_from((P *) nullptr)), P>, (int) std::is_same_v<decltype(derive_from((Twice *) nullptr)), Twice>);
  std::printf("%d %d %d\n", (int) is_closure<P>, (int) is_closure<Twice>, (int) is_closure<Plus>);
  return 0;
}

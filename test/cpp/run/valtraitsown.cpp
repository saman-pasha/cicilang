// the traits of one value over the program's classes: a deleted copy, explicit and converting constructors, a constructor
// template whose parameter does not depend on its own parameters, an assignment from another type
#include <cstdio>
#include <type_traits>
#define P(x) std::printf("%d", (int) (x))
struct NC { NC() {} NC(const NC &) = delete; NC(NC &&) = default; };
template <class C> struct Str {
  template <class A = C, std::enable_if_t<std::is_same_v<A, C>, int> = 0> Str(const C *) {}
  Str(int, C) {}
};
struct Ex { explicit Ex(int) {} };
struct Im { Im(double) {} };
struct Ptr { Ptr(const char *) {} };
struct As { As &operator=(int) { return *this; } };
struct Fw { template <class T> Fw(T &&) {} };
struct Cs { template <class T, std::enable_if_t<std::is_integral_v<T>, int> = 0> Cs(T) {} };
int main() {
  P((std::is_copy_constructible_v<NC>)); P((std::is_move_constructible_v<NC>)); P((std::is_constructible_v<NC, NC &>)); P((std::is_constructible_v<NC, NC>));
  std::puts("");
  P((std::is_constructible_v<Str<char>, int>)); P((std::is_constructible_v<Str<char>, const char *>)); P((std::is_convertible_v<int, Str<char>>));
  P((std::is_convertible_v<const char *, Str<char>>)); P((std::is_constructible_v<Str<char>, int, char>)); P((std::is_constructible_v<Str<char>, const char *, char>));
  std::puts("");
  P((std::is_constructible_v<Ex, int>)); P((std::is_convertible_v<int, Ex>)); P((std::is_constructible_v<Im, int>)); P((std::is_constructible_v<Im, const char *>));
  P((std::is_constructible_v<Ptr, int>)); P((std::is_constructible_v<Ptr, const char *>)); P((std::is_constructible_v<Ptr, std::nullptr_t>)); P((std::is_constructible_v<Ptr, double>));
  std::puts("");
  P((std::is_assignable_v<As &, int>)); P((std::is_assignable_v<As &, const char *>)); P((std::is_assignable_v<As &, double>)); P((std::is_assignable_v<As &, As>));
  std::puts("");
  P((std::is_constructible_v<Fw, int>)); P((std::is_constructible_v<Fw, const char *>)); P((std::is_constructible_v<Cs, int>)); P((std::is_constructible_v<Cs, double>));
  P((std::is_convertible_v<long, Cs>)); P((std::is_convertible_v<float, Cs>));
  std::puts("");
}

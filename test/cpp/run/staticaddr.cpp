// The address of a static data member that folds to a constant (0.191): `&S::n', `&U<T>::id' one object per instance (libc++'s
// no-RTTI std::any tells its types apart so), a bare `&n' in a member function; a base written `decltype(e)' (libc++'s
// __well_formed_deleter); a static member function whose own body names its address, taken as a value (std::any's __handle)
#include <cstdio>
struct S { static constexpr int n = 5; int get() const { const int *p = &n; return *p + 1; } };
template <class T> struct U { static constexpr int id = 0; };
template <class T> const void *tag() { return &U<T>::id; }
struct Yes { static constexpr bool value = true; };
struct No { static constexpr bool value = false; };
template <class T, class = decltype(T().size())> Yes has_size(int);
template <class> No has_size(...);
template <class T> struct HasSize : decltype(has_size<T>(0)) {};
struct Box { int size() const { return 3; } };
template <class T> struct H {
  using Fn = int (*)(int, int);
  static int handle(int act, int v) { Fn self = &H::handle; return act == 0 ? v * 10 : (act == 1 ? self(0, v + 1) : -1); }
  static Fn get() { return &H::handle; }
};
int main() {
  const int *p = &S::n;
  std::printf("static: %d %d\n", *p, S().get());
  std::printf("tags: %d %d %d\n", tag<int>() != tag<long>(), tag<int>() == tag<int>(), *(const int *) tag<char>());
  std::printf("decltype base: %d %d\n", (int) HasSize<Box>::value, (int) HasSize<int>::value);
  H<int>::Fn f = H<int>::get();
  std::printf("thunk: %d %d %d\n", f(0, 4), f(1, 4), f == &H<int>::handle);
  return 0;
}

#include <cstdio>
struct [[_Clang::__ptrauth_vtable_pointer__(process_independent, no_address_discrimination, no_extra_discrimination)]] TI { virtual ~TI() {} int v = 3; };
template <class T> const T &pick([[_Clang::__lifetimebound__]] const T &a, [[_Clang::__lifetimebound__]] const T &b) { return a < b ? b : a; }
struct S { int x = 4; const int &get() const [[_Clang::__lifetimebound__]] { return x; } int *data() [[clang::lifetimebound]] { return &x; } };
template <class T> struct W;
using WI = W<int>;
template <class T> struct [[_Clang::__preferred_name__(WI)]] W { T t; };
template <class T> struct [[_Clang::__no_specializations__("no")]] NS { T t; };
struct [[clang::capability("mutex")]] Mu { [[clang::acquire_capability()]] void lock() {} [[clang::release_capability()]] void unlock() {} };
[[gnu::always_inline]] inline int twice(int k) { return 2 * k; }
[[gnu::cold, gnu::noinline]] int cold(int k) { return k + 1; }
int main() {
  TI t; S s; W<int> w{5}; NS<int> n{6}; Mu m; m.lock(); m.unlock();
  int a = 1, b = 2;
  std::printf("%d %d %d %d %d %d %d %d\n", t.v, pick(a, b), s.get(), *s.data(), w.t, n.t, twice(3), cold(4));
  switch (a) { case 1: [[clang::fallthrough]]; case 2: std::printf("ft\n"); break; }
  std::printf("%d %d %d\n", __has_cpp_attribute(gnu::unused), __has_cpp_attribute(__gnu__::__cold__), __has_cpp_attribute(_Clang::__lifetimebound__));
  return 0;
}

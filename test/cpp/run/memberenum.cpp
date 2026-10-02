// An enum that types a data member declares its enumerators in the class: libc++ 18's __consume_result writes
// `enum : char32_t { __ok, __error } __status : 1 {__ok};' and `__consume_result::__error' names one.
#include <cstdio>
struct R {
  char32_t cp : 31;
  enum : char32_t { ok = 0, error = 1 } status : 1 {ok};
};
inline constexpr R rerr{0xFFFD, R::error};
struct T { enum Kind { a = 3, b = 5 } k = b; int n; };
int main() {
  R r{65, R::ok};
  T t{T::a, 2};
  T u{};
  std::printf("%d %d %d %d %d %d %d %d\n", (int) rerr.cp, (int) rerr.status, (int) r.cp, (int) r.status, (int) t.k, t.n, (int) u.k, (int) sizeof(R));
  return 0;
}

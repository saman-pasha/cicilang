// C++26's std::is_within_lifetime (P2641, libc++ 22; 0.234): a consteval function of the library over clang's builtin, folded by
// the evaluator, its union member alive where it is the active one, its call in `if consteval' an immediate context
#include <cstdio>
#include <type_traits>
struct OptBool {
  union { bool b; char c; };
  constexpr OptBool() : c(2) {}
  constexpr OptBool(bool v) : b(v) {}
  constexpr bool has_value() const {
    if consteval { return std::is_within_lifetime(&b); }
    return c != 2;
  }
};
consteval bool live() { int x = 1; return std::is_within_lifetime(&x); }
int main() {
  constexpr OptBool none, yes(true);
  static_assert(!none.has_value() && yes.has_value() && live());
  OptBool r(false);
  std::printf("%d %d %d %d\n", (int) none.has_value(), (int) yes.has_value(), (int) r.has_value(), (int) live());
  return 0;
}

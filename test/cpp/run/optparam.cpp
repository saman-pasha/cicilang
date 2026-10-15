// a class argument converted by a constructor TEMPLATE of the parameter's class (0.137): a template's parameters
// `const std::optional<int> &', `const std::optional<std::string> &' and `std::optional<std::locale> &&' (libc++'s
// __format_context_create) given an int, a string and a locale; and a locale is no string_view to is_convertible
#include <cstdio>
#include <locale>
#include <optional>
#include <string>
#include <string_view>
#include <type_traits>
template <class O> int k(O o, const std::optional<int> &l) { return (int) o + (l ? *l : 0); }
template <class O> int m(O o, const std::optional<std::string> &l) { return (int) o + (l ? (int) l->size() : 0); }
template <class O, class C> int f(O o, C c, std::optional<std::locale> &&l = std::nullopt) { return (int) o + (int) c + (l ? 100 : 0); }
int main() {
  std::string s = "abc";
  std::locale loc;
  std::printf("%d %d %d %d\n", k(2, 5), m(1, s), f(1, 2), f(1, 2, std::move(loc)));
  std::printf("%d %d\n", (int) std::is_convertible_v<const std::locale &, std::string_view>, (int) std::is_convertible_v<const char *, std::string_view>);
  return 0;
}

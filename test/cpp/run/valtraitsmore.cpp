// more traits of one value: references in a tuple and a pair, a union's implicit copy, a scalar from an explicit conversion, std::nullptr_t
#include <cstdio>
#include <optional>
#include <string>
#include <string_view>
#include <tuple>
#include <utility>
#include <vector>
#include <type_traits>
#define P(...) std::printf("%d", (int) (__VA_ARGS__))
union U { std::string s; int i; U() {} ~U() {} };
union V { int i; double d; };
struct EB { explicit operator bool() const { return true; } };
struct EI { explicit operator int() const { return 1; } };
int main() {
  P(std::is_constructible_v<std::tuple<int &>, int &>); P(std::is_constructible_v<std::tuple<int &>, int>); P(std::is_constructible_v<std::pair<int &, int>, int &, int>);
  P(std::is_constructible_v<std::pair<int &, int>, int, int>); P(std::is_convertible_v<std::tuple<int>, std::tuple<long>>); P(std::is_constructible_v<std::tuple<const int &>, int>);
  std::puts("");
  P(std::is_copy_constructible_v<U>); P(std::is_copy_constructible_v<V>); P(std::is_copy_assignable_v<V>); P(std::is_move_constructible_v<U>);
  std::puts("");
  P(std::is_constructible_v<int, std::optional<int>>); P(std::is_constructible_v<bool, std::optional<int>>); P(std::is_constructible_v<bool, EB>); P(std::is_constructible_v<int, EB>);
  P(std::is_constructible_v<int, EI>); P(std::is_constructible_v<long, EI>); P(std::is_convertible_v<EI, int>);
  std::puts("");
  P(std::is_constructible_v<std::string, std::nullptr_t>); P(std::is_convertible_v<const char (&)[4], std::string>); P(std::is_constructible_v<std::string_view, std::string>);
  P(std::is_convertible_v<std::string_view, const char *>); P(std::is_constructible_v<std::vector<int>, std::initializer_list<int>>); P(std::is_convertible_v<std::nullptr_t, int *>);
  P(std::is_convertible_v<int *, std::nullptr_t>); P(std::is_constructible_v<std::nullptr_t, int *>);
  std::puts("");
}

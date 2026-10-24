// the traits of one value over library classes: is_convertible, is_constructible, is_assignable
#include <cstdio>
#include <string>
#include <string_view>
#include <vector>
#include <optional>
#include <memory>
#include <functional>
#include <utility>
#include <type_traits>
#define P(x) std::printf("%d", (int) (x))
int main() {
  P((std::is_convertible_v<int, std::string>)); P((std::is_convertible_v<char, std::string>)); P((std::is_convertible_v<const char *, std::string>));
  P((std::is_convertible_v<std::string_view, std::string>)); P((std::is_convertible_v<std::string, std::string_view>)); P((std::is_convertible_v<double, std::string>));
  std::puts("");
  P((std::is_constructible_v<std::string, int>)); P((std::is_constructible_v<std::string, char>)); P((std::is_constructible_v<std::string, const char *>));
  P((std::is_constructible_v<std::string, std::string_view>)); P((std::is_constructible_v<std::string, int, char>)); P((std::is_constructible_v<std::string, double>));
  std::puts("");
  P((std::is_convertible_v<int, std::vector<int>>)); P((std::is_constructible_v<std::vector<int>, int>)); P((std::is_constructible_v<std::vector<int>, int, int>));
  P((std::is_convertible_v<std::initializer_list<int>, std::vector<int>>)); P((std::is_constructible_v<std::vector<int>, const char *>));
  std::puts("");
  P((std::is_convertible_v<int, std::optional<int>>)); P((std::is_convertible_v<int, std::optional<std::string>>)); P((std::is_constructible_v<std::optional<std::string>, const char *>));
  P((std::is_convertible_v<std::nullopt_t, std::optional<int>>)); P((std::is_constructible_v<std::optional<int>, std::string>));
  std::puts("");
  P((std::is_convertible_v<int *, std::unique_ptr<int>>)); P((std::is_constructible_v<std::unique_ptr<int>, int *>)); P((std::is_convertible_v<std::nullptr_t, std::unique_ptr<int>>));
  P((std::is_constructible_v<std::shared_ptr<int>, int>)); P((std::is_convertible_v<std::unique_ptr<int>, std::shared_ptr<int>>));
  std::puts("");
  P((std::is_convertible_v<int (*)(int), std::function<int(int)>>)); P((std::is_convertible_v<int, std::function<int(int)>>)); P((std::is_constructible_v<std::function<void()>, int>));
  std::puts("");
  P((std::is_convertible_v<std::pair<int, int>, std::pair<long, long>>)); P((std::is_constructible_v<std::pair<int, std::string>, int, const char *>)); P((std::is_constructible_v<std::pair<int, std::string>, int, int>));
  std::puts("");
  P((std::is_assignable_v<std::string &, int>)); P((std::is_assignable_v<std::string &, const char *>)); P((std::is_assignable_v<std::string &, std::vector<int>>));
  P((std::is_assignable_v<std::vector<int> &, int>)); P((std::is_assignable_v<std::optional<int> &, int>));
  std::puts("");
}

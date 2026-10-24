// the traits of several values and of one value over more library classes
#include <cstdio>
#include <string>
#include <string_view>
#include <vector>
#include <tuple>
#include <variant>
#include <any>
#include <optional>
#include <memory>
#include <utility>
#include <type_traits>
#define P(x) std::printf("%d", (int) (x))
struct Ex { explicit Ex(int) {} };
struct Im { Im(int) {} };
struct Two { Two(int, const char *) {} };
int main() {
  P((std::is_constructible_v<Ex, int>)); P((std::is_convertible_v<int, Ex>)); P((std::is_constructible_v<Im, int>)); P((std::is_convertible_v<int, Im>));
  P((std::is_constructible_v<Ex, const char *>)); P((std::is_constructible_v<Two, int, const char *>)); P((std::is_constructible_v<Two, int, int>)); P((std::is_constructible_v<Two, const char *, int>));
  std::puts("");
  P((std::is_constructible_v<std::tuple<int, std::string>, int, const char *>)); P((std::is_constructible_v<std::tuple<int, std::string>, int, int>));
  P((std::is_convertible_v<std::tuple<int, int>, std::tuple<long, long>>)); P((std::is_constructible_v<std::tuple<std::string>, int>));
  std::puts("");
  P((std::is_constructible_v<std::variant<int, std::string>, const char *>)); P((std::is_constructible_v<std::variant<int, std::string>, std::vector<int>>));
  P((std::is_convertible_v<int, std::variant<int, std::string>>)); P((std::is_constructible_v<std::any, int>)); P((std::is_convertible_v<std::string, std::any>));
  std::puts("");
  P((std::is_constructible_v<std::string_view, const char *>)); P((std::is_constructible_v<std::string_view, int>)); P((std::is_convertible_v<std::string, std::string_view>));
  P((std::is_constructible_v<std::string_view, const char *, std::size_t>)); P((std::is_constructible_v<std::string_view, int, int>));
  std::puts("");
  P((std::is_nothrow_constructible_v<std::string, const char *>)); P((std::is_nothrow_constructible_v<std::string_view, const char *>)); P((std::is_nothrow_constructible_v<std::optional<int>, int>));
  P((std::is_nothrow_convertible_v<int, std::optional<int>>));
  std::puts("");
  P((std::is_constructible_v<std::unique_ptr<int>, int *, std::default_delete<int>>)); P((std::is_constructible_v<std::unique_ptr<int>, int>)); P((std::is_constructible_v<std::shared_ptr<int>, int *>));
  P((std::is_constructible_v<std::shared_ptr<int>, std::unique_ptr<int>>)); P((std::is_constructible_v<std::shared_ptr<int>, std::unique_ptr<double>>));
  std::puts("");
}

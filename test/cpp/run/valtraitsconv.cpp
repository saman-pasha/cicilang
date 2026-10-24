// a class to a scalar: only through a conversion function whose result converts; and a scalar to a scalar
#include <cstdio>
#include <string>
#include <string_view>
#include <optional>
#include <memory>
#include <type_traits>
#define P(x) std::printf("%d", (int) (x))
struct ToInt { operator int() const { return 1; } };
struct ToPtr { operator const char *() const { return ""; } };
struct ExInt { explicit operator int() const { return 1; } };
struct ToBool { explicit operator bool() const { return true; } };
int main() {
  P((std::is_convertible_v<std::string, int>)); P((std::is_constructible_v<int, std::string>)); P((std::is_convertible_v<std::string, const char *>));
  P((std::is_convertible_v<std::string, std::string_view>)); P((std::is_constructible_v<bool, std::optional<int>>)); P((std::is_convertible_v<std::optional<int>, bool>));
  P((std::is_constructible_v<bool, std::unique_ptr<int>>)); P((std::is_convertible_v<std::unique_ptr<int>, bool>));
  std::puts("");
  P((std::is_convertible_v<ToInt, int>)); P((std::is_convertible_v<ToInt, long>)); P((std::is_convertible_v<ToInt, const char *>)); P((std::is_convertible_v<ToPtr, const char *>));
  P((std::is_convertible_v<ToPtr, int>)); P((std::is_convertible_v<ExInt, int>)); P((std::is_constructible_v<int, ExInt>)); P((std::is_constructible_v<bool, ToBool>)); P((std::is_convertible_v<ToBool, bool>));
  std::puts("");
  P((std::is_convertible_v<int, double>)); P((std::is_convertible_v<int *, void *>)); P((std::is_convertible_v<void *, int *>)); P((std::is_convertible_v<int, int *>));
  P((std::is_convertible_v<std::nullptr_t, int *>)); P((std::is_convertible_v<int *, bool>)); P((std::is_constructible_v<int *, std::nullptr_t>)); P((std::is_constructible_v<double, int *>));
  std::puts("");
}

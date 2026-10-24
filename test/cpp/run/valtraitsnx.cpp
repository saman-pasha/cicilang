// is_nothrow_convertible: a conversion through a constructor that may throw, which libc++ 18 asks of the noexcept operator
#include <cstdio>
#include <optional>
#include <string>
#include <type_traits>
struct NX { NX(int) noexcept {} };
struct TH { TH(int) {} };
int main() {
  std::printf("%d %d %d %d %d %d\n", (int) std::is_nothrow_convertible_v<int, std::optional<int>>, (int) std::is_nothrow_convertible_v<int, NX>,
              (int) std::is_nothrow_convertible_v<int, TH>, (int) std::is_nothrow_convertible_v<const char *, std::string>, (int) std::is_nothrow_convertible_v<int, long>,
              (int) std::is_nothrow_convertible_v<std::optional<int>, std::optional<int>>);
}

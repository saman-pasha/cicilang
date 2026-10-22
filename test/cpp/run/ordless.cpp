// The orderings' `less' over <string> (0.186): <string> reads libc++'s class template `std::__less' before <compare>,
// and `partial_ordering::less(_PartialOrdResult::__less)' was read as a member function's declaration, so the static
// had no definition (`auto w = std::weak_ordering::less;' was refused, `auto(w)'); and `auto p = 1.0 <=> 2.0;' was a
// double.
#include <cstdio>
#include <string>

int main() {
  std::string a = "ab", b = "ac";
  auto r = a <=> b;
  auto w = std::weak_ordering::less;
  auto p = 1.0 <=> 2.0;
  std::printf("%d %d %d %d\n", (int) (r == std::strong_ordering::less), (int) (w < 0),
              (int) (p == std::partial_ordering::less), (int) (std::strong_ordering::less < 0));
  return 0;
}

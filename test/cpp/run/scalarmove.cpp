#include <cstdio>
#include <optional>
#include <type_traits>
#include <utility>
// `std::move' of a scalar is an xvalue ([expr.move], [temp.deduct.call]/3): a forwarding reference deduces the plain
// type, an overload taking `T &&' is chosen over one taking `T &', in a function, a template and through a forwarding
// call that returns `optional<T>', as libc++'s parallel `__reduce' does
template <class T> int kind(T &&) { return std::is_lvalue_reference_v<T> ? 1 : 2; }
static int over(int &) { return 1; }
static int over(int &&) { return 2; }
static int over2(int *&) { return 1; }
static int over2(int *&&) { return 2; }
template <class T> int outer(T v) { return kind(std::move(v)) * 10 + kind(v); }
static int g(long y) { return kind(std::move(y)) * 10 + kind(y); }
template <class P, class I, class T>
std::optional<T> red(P &&, I &&f, T &&init) noexcept { return std::optional<T>(init + f); }
template <class P, class I, class T>
T reduce(P &&p, I f, T init) {
  auto r = red(p, std::move(f), std::move(init));
  static_assert(std::is_same_v<decltype(r), std::optional<T>>);
  return *std::move(r);
}
enum Color { Red, Green };
int main() {
  int p = 0;
  long x = 3;
  int i = 7;
  int *ptr = &i;
  Color c = Green;
  std::printf("%d %d %d %d %d\n", kind(x), kind(std::move(x)), kind(static_cast<long &&>(x)), outer(4L), g(5));
  std::printf("%d %d %d %d %d\n", over(i), over(std::move(i)), over2(ptr), over2(std::move(ptr)), kind(std::move(c)));
  std::printf("%ld %d %d\n", reduce(p, 1, 5L), std::move(i) + 1, *std::move(ptr));
  return 0;
}

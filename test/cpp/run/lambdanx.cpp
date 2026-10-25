#include <cstdio>
#include <type_traits>
#include <utility>
struct M { int f(int) noexcept(false) { return 1; } int g(int) noexcept { return 2; } };
template <bool B> struct W { void h() noexcept(B) {} };
typedef void FN() noexcept;
typedef void FT();
void nf() noexcept {}
void tf() {}
int main() {
  auto a = [](int x) { return x + 1; };
  auto b = [](int x) noexcept { return x + 1; };
  auto c = [](int x) noexcept(false) { return x; };
  auto d = [](auto x) noexcept(sizeof(x) > 4) { return x; };
  std::printf("%d %d %d\n", noexcept(a(1)), noexcept(b(1)), noexcept(c(1)));
  std::printf("%d %d\n", noexcept(d(1)), noexcept(d(1.0)));
  std::printf("%d %d %d\n", (int) std::is_nothrow_invocable_v<decltype(a), int>, (int) std::is_nothrow_invocable_v<decltype(b), int>,
              (int) std::is_nothrow_invocable_v<decltype(c), int>);
  FN *p = nf; FT *q = tf;
  std::printf("%d %d\n", noexcept(p()), noexcept(q()));
  auto r = &nf; auto s = &tf;
  std::printf("%d %d\n", noexcept(r()), noexcept(s()));
  using MF = int (M::*)(int) noexcept;
  MF mg = &M::g; M m;
  std::printf("%d\n", noexcept((m.*mg)(1)));
  void (W<true>::*wt)() noexcept = &W<true>::h;
  W<true> w;
  std::printf("%d %d\n", noexcept((w.*wt)()), noexcept(W<false>().h()));
  void (*fp)() noexcept(true) = nf;
  std::printf("%d\n", noexcept(fp()));
  return 0;
}

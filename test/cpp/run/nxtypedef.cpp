#include <cstdio>
#include <type_traits>
typedef void FC() noexcept(sizeof(int) > 8);
typedef void FD() noexcept(sizeof(int) < 8);
constexpr bool yes() { return true; }
typedef void FE() noexcept(yes());
template <bool B> struct W { typedef void F() noexcept(B); };
void tf() {}
void nf() noexcept {}
int main() {
  FC *p = tf; FD *q = nf; FE *r = nf;
  W<false>::F *s = tf; W<true>::F *t = nf;
  std::printf("%d %d %d %d %d\n", noexcept(p()), noexcept(q()), noexcept(r()), noexcept(s()), noexcept(t()));
  std::printf("%d %d %d %d\n", (int) std::is_same_v<FC, void()>, (int) std::is_same_v<FD, void() noexcept>,
              (int) std::is_same_v<W<false>::F, void()>, (int) std::is_same_v<W<true>::F, void() noexcept>);
  return 0;
}

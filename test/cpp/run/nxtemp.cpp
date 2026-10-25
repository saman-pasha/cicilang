#include <cstdio>
template <bool B> struct W { void h() noexcept(B) {} };
struct P { void h() noexcept(false) {} void g() noexcept {} };
int main() {
  W<false> w2; W<true> w3;
  std::printf("%d %d %d %d\n", noexcept(W<false>().h()), noexcept(w2.h()), noexcept(w3.h()), noexcept(W<true>().h()));
  std::printf("%d %d %d\n", noexcept(P().h()), noexcept(P().g()), noexcept(W<false>{}.h()));
  return 0;
}

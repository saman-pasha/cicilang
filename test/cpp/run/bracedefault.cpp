// `m{}' of a class whose defaulted default constructor has nothing to do: zeroed, an empty member left alone
#include <cstdio>
struct E {
  E() = default;
  E(int) {}
};
struct K {
  K() = default;
  explicit K(int x) : v(x) {}
  int v;
};
struct W {
  [[no_unique_address]] E e{};
  int k = 3;
  K kk{};
};
int main() {
  W w;
  W w2{};
  std::printf("%d %d %d %d\n", w.k, w.kk.v, w2.k, w2.kk.v);
  return 0;
}

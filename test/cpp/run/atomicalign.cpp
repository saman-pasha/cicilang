#include <cstdio>
#include <cstddef>
template <class T> struct R {
  static constexpr std::size_t req = sizeof(T);
  using AT [[__gnu__::__aligned__(req)]] = T;
  AT *p;
  T load() const { T r; __atomic_load(p, &r, 5); return r; }
};
struct P { short a, b; };
using AP [[gnu::aligned(4)]] = P;
int main() {
  alignas(4) P x{5, 6};
  R<P> r{&x};
  P y = r.load();
  AP *q = &x; P z; __atomic_load(q, &z, 5);
  std::printf("%d %d %d %d %d\n", y.a, y.b, z.a, (int) alignof(R<P>::AT), (int) alignof(AP));
  return 0;
}

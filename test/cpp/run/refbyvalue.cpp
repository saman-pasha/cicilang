// A reference handed to a by-value aggregate parameter is read through: the value of a cast to a reference, and of a
// forwarding reference, is the referent's address, and the parameter takes the object's bytes (0.112)
#include <cstdio>
#include <utility>
struct Mono {};
struct Two { int a = 4; int b = 5; };
struct Big { long x[4] = {1, 2, 3, 4}; };
int take(Two t) { return t.a + t.b; }
int big(Big b) { return (int) (b.x[0] + b.x[3]); }
int mono(Mono) { return 1; }
int via_cast(Two &r) { return take(static_cast<Two &>(r)); }
int via_forward(Two &r) { return take(std::forward<Two &>(r)); }
int big_cast(Big &b) { return big(static_cast<Big &>(b)); }
template <class F, class A> int call(F &&f, A &&a) { return static_cast<F &&>(f)(static_cast<A &&>(a)); }
int main() {
  Two t;
  Big b;
  Mono m;
  std::printf("%d %d %d\n", via_cast(t), via_forward(t), big_cast(b));
  auto g = [](auto x) { return x.a * x.b; };
  auto h = [](auto) { return 7; };
  std::printf("%d %d %d\n", call(g, t), call(h, m), call(mono, m));
  return 0;
}

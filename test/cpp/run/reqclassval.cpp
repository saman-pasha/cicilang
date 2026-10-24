// a requires-clause that builds class values and calls their constexpr members and operators: the program's class and chrono's durations
#include <chrono>
#include <cstdio>
using namespace std::chrono;
struct Len { int v; constexpr Len(int x) : v(x) {} constexpr bool operator<(Len o) const { return v < o.v; } constexpr int twice() const { return 2 * v; } };
template <class T> requires(T{2} < T{3}) int g1(T) { return 1; }
int g1(...) { return 0; }
template <class T> requires(T{3} < T{2}) int g2(T) { return 1; }
int g2(...) { return 0; }
template <class T> requires(T{4}.twice() == 8) int g3(T) { return 1; }
int g3(...) { return 0; }
template <class D> requires(D{1}.count() == 1) int f1(D) { return 1; }
int f1(...) { return 0; }
template <class D> requires(D{1} < D{2}) int f2(D) { return 1; }
int f2(...) { return 0; }
template <class D> requires(seconds(D{1}).count() == 1) int f3(D) { return 1; }
int f3(...) { return 0; }
template <class D> requires(D{1} < days{1}) int f4(D) { return 1; }
int f4(...) { return 0; }
template <class D> requires(days{1} < D{1}) int f5(D) { return 1; }
int f5(...) { return 0; }
int main() {
  std::printf("%d %d %d\n", g1(Len{1}), g2(Len{1}), g3(Len{1}));
  std::printf("%d %d %d %d %d\n", f1(seconds{5}), f2(seconds{5}), f3(seconds{5}), f4(seconds{5}), f5(seconds{5}));
  std::printf("%d %d\n", f4(hours{5}), f4(weeks{1}));
}

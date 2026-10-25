// libc++'s atomics over what no one instruction does: a floating fetch_add and += of a long double (C++20), a float's
// compare_exchange_strong, a struct of twelve bytes' exchange and compare_exchange_strong, a pointer's ++, += and fetch_sub.
// The struct's exchange succeeds, as C++20 has it (padding bits ignored, P0528): clang++ over libstdc++ prints this line; over
// libc++ 18 and 21 clang++ lays std::atomic<S12> in sixteen bytes and its compare-exchange fails over their padding (`1 0 4 6')
#include <atomic>
#include <cstdio>
struct S12 { int i[3]; };
int main() {
  std::atomic<long double> ld{1.5L};
  long double o1 = ld.fetch_add(2.25L);
  ld += 1.0L;
  std::atomic<float> f{2.0f};
  float e = 2.0f;
  bool ok = f.compare_exchange_strong(e, 3.5f);
  float e2 = 9.0f;
  bool no = f.compare_exchange_strong(e2, 1.0f);
  std::atomic<S12> s{S12{{1, 2, 3}}};
  S12 old = s.exchange(S12{{4, 5, 6}});
  S12 ex{{4, 5, 6}};
  bool sok = s.compare_exchange_strong(ex, S12{{7, 8, 9}});
  S12 cur = s.load();
  int arr[8] = {};
  std::atomic<int *> p{arr};
  p++; p += 3; p.fetch_sub(1);
  std::printf("%.4Lf %.4Lf | %d %d %.2f %.2f | %d %d %d %d %d\n", o1, ld.load(), ok, no, f.load(), e2, old.i[0], sok, cur.i[0], cur.i[2], int(p.load() - arr));
  return 0;
}

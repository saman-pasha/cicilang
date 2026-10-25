// <atomic>'s C++20 facilities by their feature-test macros (0.206): atomic_flag::test, a floating atomic's fetch_add
// and fetch_sub (atomicrmw fadd and fsub), the lock-free aliases, value-initialized atomics, wait and notify, and an
// atomic of a struct aligned at its size and moved as one integer.
#include <atomic>
#include <cstdio>
#include <type_traits>

struct Pt { int x, y; };

int main() {
  std::atomic_flag f;
  std::printf("flag %d", (int) f.test());
  std::printf(" %d", (int) f.test_and_set());
  std::printf(" %d", (int) f.test());
  f.clear();
  std::printf(" %d\n", (int) f.test());
  std::atomic<float> af{1.5f};
  float o = af.fetch_add(2.25f);
  af -= 0.75f;
  std::printf("float %.2f %.2f\n", o, af.load());
  std::atomic<double> ad{10.0};
  ad.fetch_sub(2.5);
  std::printf("double %.2f\n", ad.load());
  std::atomic_signed_lock_free sl{-3};
  std::atomic_unsigned_lock_free ul{3};
  sl.fetch_add(1);
  ul.fetch_add(1);
  std::printf("lock_free %lld %llu %d %d\n", (long long) sl.load(), (unsigned long long) ul.load(),
              (int) std::is_signed_v<std::atomic_signed_lock_free::value_type>, (int) decltype(sl)::is_always_lock_free);
  std::atomic<int> vi;
  std::atomic<Pt> vp;
  std::printf("value_init %d %d %d\n", vi.load(), vp.load().x, vp.load().y);
  std::atomic<int> w{5};
  w.wait(4);
  w.notify_all();
  std::printf("wait %d\n", w.load());
  std::printf("lock_free_p %d %d\n", (int) std::atomic<long>::is_always_lock_free, (int) w.is_lock_free());
  std::printf("layout %zu %zu %zu %zu %d\n", sizeof(std::atomic<Pt>), alignof(std::atomic<Pt>), alignof(Pt), alignof(std::atomic<double>),
              (int) std::atomic<Pt>::is_always_lock_free);
}

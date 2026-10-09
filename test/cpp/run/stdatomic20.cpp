// <atomic> at C++20 (0.117): store, load, fetch_add, is_lock_free, and wait / notify_one / notify_all -- the C++20 members whose symbols libc++ ships
// (`__cxx_atomic_notify_one(void const volatile *)', `__libcpp_atomic_wait', `__libcpp_atomic_monitor'). Two defects stood between them and a run: the
// enum `memory_order : __memory_order_underlying_t' (a typedef of `underlying_type<...>::type') reached the lowering with the template-id unresolved,
// and the mangler spelled the parameter `PKv' for `PVKv'
#include <atomic>
#include <cstdio>
int main() {
  std::atomic<int> a(5);
  a.store(7);
  a.notify_one();
  a.wait(3);
  std::printf("%d %d\n", a.load(), (int)a.is_lock_free());
  std::atomic<int> b(0);
  b.wait(1);
  b.fetch_add(2);
  b.notify_all();
  std::printf("%d\n", b.load());
  return 0;
}

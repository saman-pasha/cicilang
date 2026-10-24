#include <stdatomic.h>
#include <cstdio>
// C++23's <stdatomic.h>: C's atomic names over std::atomic
int main() {
  atomic_int a = 5;
  atomic_fetch_add(&a, 3);
  atomic_store_explicit(&a, atomic_load(&a) * 2, memory_order_release);
  int e = 16;
  bool ok = atomic_compare_exchange_strong(&a, &e, 20);
  atomic_flag f = ATOMIC_FLAG_INIT;
  bool was = atomic_flag_test_and_set(&f);
  atomic_thread_fence(memory_order_seq_cst);
  std::printf("%d %d %d %d\n", atomic_load_explicit(&a, memory_order_acquire), (int) ok, (int) was, (int) atomic_is_lock_free(&a));
  return 0;
}

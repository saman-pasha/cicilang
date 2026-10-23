// C++20's std::atomic_ref (libc++ 21): is_always_lock_free over GCC's __atomic_always_lock_free with an aligned pointer,
// is_lock_free over __atomic_is_lock_free, and the operations through a reference to a plain object, which libc++ writes
// on GCC's generic builtins __atomic_load, __atomic_store and __atomic_exchange (0.194)
#include <atomic>
#include <cstdio>
struct alignas(8) Pair { int a, b; };
int main() {
    int n = 5;
    std::atomic_ref<int> r(n);
    r.fetch_add(3);
    r.store(r.load() * 2);
    long l = 7;
    std::atomic_ref<long> rl(l);
    long old = rl.exchange(9);
    alignas(8) Pair p{1, 2};
    std::atomic_ref<Pair> rp(p);
    Pair q = rp.load();
    std::printf("%d %ld %ld %d %d\n", n, old, l, q.a, q.b);
    std::printf("%d %d %d %d\n", (int) std::atomic_ref<int>::is_always_lock_free, (int) std::atomic_ref<Pair>::is_always_lock_free,
                (int) r.is_lock_free(), (int) std::atomic<long>::is_always_lock_free);
    return 0;
}

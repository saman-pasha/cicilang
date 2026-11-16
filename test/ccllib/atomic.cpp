// the twin of atomic.c over std::atomic (phase 2): clang++ builds it over libc++ and it prints atomic.expect
#include <atomic>
#include <cstdio>

int main() {
    std::atomic<int> a{0};
    std::printf("load0 %d\n", a.load());
    a.store(5);
    std::printf("store %d\n", a.load());
    int old = a.exchange(7);
    std::printf("exchange %d %d\n", old, a.load());
    old = a.fetch_add(3);
    std::printf("add %d %d\n", old, a.load());
    old = a.fetch_sub(1);
    std::printf("sub %d %d\n", old, a.load());
    old = a.fetch_and(13);
    std::printf("and %d %d\n", old, a.load());
    old = a.fetch_or(2);
    std::printf("or %d %d\n", old, a.load());
    old = a.fetch_xor(1);
    std::printf("xor %d %d\n", old, a.load());
    int e = 7;
    std::printf("cas0 %d %d %d\n", (int)a.compare_exchange_strong(e, 4), a.load(), e);
    std::printf("cas1 %d %d %d\n", (int)a.compare_exchange_strong(e, 4), a.load(), e);
    std::printf("weak %d %d\n", (int)a.compare_exchange_weak(e, 6), a.load());
    std::printf("lockfree %d\n", (int)a.is_lock_free());

    std::atomic<unsigned> u{0};
    u.store(4294967295u);
    old = (int)u.fetch_add(2);
    std::printf("wrap %u %u\n", (unsigned)old, u.load());

    std::atomic<double> d{0};
    d.store(2.5);
    std::printf("double %g %g\n", d.load(), d.exchange(4.5));

    std::atomic_flag f = ATOMIC_FLAG_INIT;
    std::printf("flag %d %d %d\n", (int)f.test_and_set(), (int)f.test_and_set(), (f.clear(), (int)f.test_and_set()));
    return 0;
}

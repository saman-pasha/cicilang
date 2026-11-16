/* ccllib phase 2 (CCLLIB.md): <atomic.pl>, built by cicilang as C and by cicilang++ as C++, and compared with
   atomic.cpp over std::atomic, which clang++ builds. The three print atomic.expect. */
#include <stdio.h>
#include <atomic.pl>

int main(void) {
    atomic<int> a;
    printf("load0 %d\n", (int)load(a));
    store(a, 5);
    printf("store %d\n", (int)load(a));
    int old = exchange(a, 7);
    printf("exchange %d %d\n", old, (int)load(a));
    old = fetch_add(a, 3);
    printf("add %d %d\n", old, (int)load(a));
    old = fetch_sub(a, 1);
    printf("sub %d %d\n", old, (int)load(a));
    old = fetch_and(a, 13);
    printf("and %d %d\n", old, (int)load(a));
    old = fetch_or(a, 2);
    printf("or %d %d\n", old, (int)load(a));
    old = fetch_xor(a, 1);
    printf("xor %d %d\n", old, (int)load(a));
    int e = 7;
    printf("cas0 %d %d %d\n", compare_exchange_strong(a, &e, 4), (int)load(a), e);
    printf("cas1 %d %d %d\n", compare_exchange_strong(a, &e, 4), (int)load(a), e);
    printf("weak %d %d\n", compare_exchange_weak(a, &e, 6), (int)load(a));
    printf("lockfree %d\n", is_lock_free(a));

    atomic<unsigned> u;
    store(u, 4294967295u);
    old = fetch_add(u, 2);
    printf("wrap %u %u\n", (unsigned)old, (unsigned)load(u));

    atomic<double> d;
    store(d, 2.5);
    printf("double %g %g\n", (double)load(d), (double)exchange(d, 4.5));

    atomic_flag<> f;
    printf("flag %d %d %d\n", test_and_set(f), test_and_set(f), (clear(f), test_and_set(f)));
    return 0;
}

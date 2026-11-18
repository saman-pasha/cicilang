/* ccllib phase 2 (CCLLIB.md): <mutex.pl>, built by cicilang as C and by cicilang++ as C++, and compared with mutex.cpp
   over std::mutex, std::lock_guard, std::unique_lock, std::latch and std::barrier. The three print mutex.expect. */
#include <stdio.h>
#include <mutex.pl>

int main(void) {
    mutex<> m;
    printf("try %d\n", (int)try_lock(m));
    unlock(m);
    lock(m);
    unlock(m);
    printf("lock ok\n");

    {
        lock_guard<mutex<> > g = &m;
        printf("guard\n");
    }
    printf("after guard\n");
    lock(m);
    unlock(m);
    printf("reusable\n");

    unique_lock<mutex<> > u = &m;
    printf("owns %d\n", (int)owns_lock(u));
    unlock(u);
    printf("owns %d\n", (int)owns_lock(u));
    lock(u);
    printf("owns %d\n", (int)owns_lock(u));
    unlock(u);
    printf("owns %d\n", (int)owns_lock(u));
    printf("utry %d\n", (int)try_lock(u));
    printf("owns %d\n", (int)owns_lock(u));
    unlock(u);
    printf("owns %d\n", (int)owns_lock(u));

    latch<> l = 2L;
    printf("latch %d\n", (int)try_wait(&l));
    count_down(&l, 1);
    printf("latch %d\n", (int)try_wait(&l));
    count_down(&l, 1);
    printf("latch %d\n", (int)try_wait(&l));
    wait(&l);
    printf("waited\n");

    barrier<int> b = 1;
    arrive_and_wait(b);
    printf("barrier\n");
    return 0;
}

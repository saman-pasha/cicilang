/* ccllib phase 2 (CCLLIB.md): <mutex.pl>, built by cicilang as C and by cicilang++ as C++, and compared with mutex.cpp
   over std::mutex, std::lock_guard, std::unique_lock, std::latch and std::barrier. The three print mutex.expect. The
   threads (1.6.5): two that lock one mutex 200000 times each, a first lock from two threads at once, a latch that two
   threads count down, a barrier of three threads, and a try_lock from a thread while main holds the mutex. */
#include <stdio.h>
#include <pthread.h>
#include <mutex.pl>

static mutex<> cm;
static long counter;
static mutex<> first;
static int firsts;
static void *work(void *arg) {
    (void)arg;
    lock(first); firsts++; unlock(first);
    for (int i = 0; i < 200000; i++) { lock(cm); counter++; unlock(cm); }
    return 0;
}
static void *down(void *arg) { count_down((latch<> *)arg, 1); return 0; }
static void *meet(void *arg) { arrive_and_wait(*(barrier<int> *)arg); return 0; }
static void *probe(void *arg) { mutex<> *m = (mutex<> *)arg; int got = try_lock(*m); if (got) unlock(*m); return (void *)(long)got; }

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

    pthread_t t1, t2, t3;
    pthread_create(&t1, 0, work, 0);
    pthread_create(&t2, 0, work, 0);
    pthread_join(t1, 0);
    pthread_join(t2, 0);
    printf("threads %ld %d\n", counter, firsts);
    latch<> l2 = 2L;
    pthread_create(&t1, 0, down, &l2);
    pthread_create(&t2, 0, down, &l2);
    wait(&l2);
    pthread_join(t1, 0);
    pthread_join(t2, 0);
    printf("latch threads %d\n", (int)try_wait(&l2));
    barrier<int> b3 = 3;
    pthread_create(&t1, 0, meet, &b3);
    pthread_create(&t2, 0, meet, &b3);
    pthread_create(&t3, 0, meet, &b3);
    pthread_join(t1, 0);
    pthread_join(t2, 0);
    pthread_join(t3, 0);
    printf("barrier threads\n");
    mutex<> held;
    lock(held);
    void *r;
    pthread_create(&t1, 0, probe, &held);
    pthread_join(t1, &r);
    printf("held %d\n", (int)(long)r);
    unlock(held);
    pthread_create(&t1, 0, probe, &held);
    pthread_join(t1, &r);
    printf("free %d\n", (int)(long)r);
    return 0;
}

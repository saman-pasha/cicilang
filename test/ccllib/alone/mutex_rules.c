/* the rules of <mutex.pl>'s first use (1.6.5), read from the instances' own fields: a mutex, a latch and a barrier are
   born with no live pthread object, state 0, and their first use -- a lock, a count_down, a latch's value, an arrival
   -- leaves it live, state 2, so that a latch or a barrier returned by value holds no live object; and a first use that
   meets another's, state 1, waits for it, so that no thread uses the object before it is initialized. glibc's zero
   mutex and condition are initialized ones and its mutex copies whole, so no run on Linux tells these rules from their
   breach: the fields do. Built as C and as C++; it has no twin, since C++ says nothing of the state. */
#include <stdio.h>
#include <pthread.h>
#include <time.h>
#include <mutex.pl>
static int checks, bad;
static void rule(int ok) { checks++; if (!ok) bad++; }
static mutex<> busy;
static int initialized;
static void *meet(void *arg) {
    (void)arg;
    int got = try_lock(busy);
    int seen = __atomic_load_n(&initialized, 2);
    if (got) unlock(busy);
    return (void *)(long)(got && seen);
}
int main(void) {
    mutex<> m;
    rule(m.ready == 0);
    lock(m);
    rule(m.ready == 2);
    unlock(m);
    latch<> l = 3L;
    rule(l.ready == 0);
    rule(latch_value(&l) == 3);
    rule(l.ready == 2);
    latch<> l2 = 1L;
    rule(l2.ready == 0);
    count_down(&l2, 1);
    rule(l2.ready == 2 && try_wait(&l2));
    barrier<int> b = 1;
    rule(b.ready == 0);
    arrive_and_wait(b);
    rule(b.ready == 2);
    barrier<int> b2 = 2;
    rule(b2.ready == 0);
    rule(arrive(b2) == 0);
    rule(b2.ready == 2);
    rule(arrive(b2) == 1);
    /* another thread's first use is under way, state 1: a lock waits until the object is live */
    busy.ready = 1;
    pthread_t t;
    pthread_create(&t, 0, meet, 0);
    struct timespec pause = { 0, 200000000 };
    nanosleep(&pause, 0);
    pthread_mutex_init(&busy.m_, 0);
    __atomic_store_n(&initialized, 1, 3);
    __atomic_store_n(&busy.ready, 2, 3);
    void *r;
    pthread_join(t, &r);
    rule((long)r == 1);
    printf("the rules held at %d checks%s\n", checks, bad ? ", and broke" : "");
    return bad != 0;
}

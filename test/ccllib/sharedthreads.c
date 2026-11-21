/* ccllib 1.6.5: shared_ptr and weak_ptr over threads -- four threads each clone a shared_ptr 20000 times, count its
   owners, take a weak_ptr of the clone and lock it, reset the lock, and make and drop a block of their own, each
   through the pool's lock; the count is back to 1 and every block is freed. Built by cicilang as C and by cicilang++ as
   C++, and compared with sharedthreads.cpp over std::shared_ptr, std::weak_ptr and std::thread. Through 1.6.4 the
   counts and the slots had no lock: a run stopped with `double free or corruption' in two runs of five. */
#include <stdio.h>
#include <pthread.h>
#include <memory.pl>
static void *work(void *arg) {
    shared_ptr<long> *p = (shared_ptr<long> *)arg;
    long sum = 0;
    int bad = 0;
    for (int i = 0; i < 20000; i++) {
        shared_ptr<long> c = clone(*p);
        sum += *c;
        if (use_count(c) < 2) bad++;
        weak_ptr<long> w = c;
        shared_ptr<long> l = lock(w);
        if (get(l) == 0 || expired(w)) bad++;
        reset(l);
        shared_ptr<long> mine = make_shared<long>(i);
        sum += *mine - i;
    }
    return (void *)(long)(sum == 20000L * 3 && bad == 0 ? 1 : 0);
}
int main(void) {
    shared_ptr<long> p = make_shared<long>(3L);
    pthread_t t[4];
    for (int k = 0; k < 4; k++) pthread_create(&t[k], 0, work, &p);
    int ok = 0;
    for (int k = 0; k < 4; k++) { void *r; pthread_join(t[k], &r); ok += (int)(long)r; }
    printf("threads %d count %d value %ld\n", ok, (int)use_count(p), *p);
    return 0;
}

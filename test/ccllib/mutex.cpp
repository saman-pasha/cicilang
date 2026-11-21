// the twin of mutex.c over std::mutex, std::lock_guard, std::unique_lock, std::latch and std::barrier (phase 2):
// clang++ builds it over libc++ and it prints mutex.expect
#include <atomic>
#include <barrier>
#include <cstdio>
#include <latch>
#include <mutex>
#include <thread>

static std::mutex cm;
static long counter;
static std::mutex first;
static int firsts;
static void work() {
    first.lock(); firsts++; first.unlock();
    for (int i = 0; i < 200000; i++) { cm.lock(); counter++; cm.unlock(); }
}

int main() {
    std::mutex m;
    std::printf("try %d\n", (int)m.try_lock());
    m.unlock();
    m.lock();
    m.unlock();
    std::printf("lock ok\n");

    {
        std::lock_guard<std::mutex> g(m);
        std::printf("guard\n");
    }
    std::printf("after guard\n");
    m.lock();
    m.unlock();
    std::printf("reusable\n");

    std::unique_lock<std::mutex> u(m);
    std::printf("owns %d\n", (int)u.owns_lock());
    u.unlock();
    std::printf("owns %d\n", (int)u.owns_lock());
    u.lock();
    std::printf("owns %d\n", (int)u.owns_lock());
    u.unlock();
    std::printf("owns %d\n", (int)u.owns_lock());
    std::printf("utry %d\n", (int)u.try_lock());
    std::printf("owns %d\n", (int)u.owns_lock());
    u.unlock();
    std::printf("owns %d\n", (int)u.owns_lock());

    std::latch l(2);
    std::printf("latch %d\n", (int)l.try_wait());
    l.count_down(1);
    std::printf("latch %d\n", (int)l.try_wait());
    l.count_down(1);
    std::printf("latch %d\n", (int)l.try_wait());
    l.wait();
    std::printf("waited\n");

    std::barrier<> b(1);
    b.arrive_and_wait();
    std::printf("barrier\n");

    std::thread t1(work), t2(work);
    t1.join();
    t2.join();
    std::printf("threads %ld %d\n", counter, firsts);
    std::latch l2(2);
    std::thread d1([&] { l2.count_down(1); }), d2([&] { l2.count_down(1); });
    l2.wait();
    d1.join();
    d2.join();
    std::printf("latch threads %d\n", (int)l2.try_wait());
    std::barrier<> b3(3);
    std::thread m1([&] { b3.arrive_and_wait(); }), m2([&] { b3.arrive_and_wait(); }), m3([&] { b3.arrive_and_wait(); });
    m1.join();
    m2.join();
    m3.join();
    std::printf("barrier threads\n");
    std::mutex held;
    held.lock();
    int r = -1;
    std::thread p1([&] { r = held.try_lock(); if (r) held.unlock(); });
    p1.join();
    std::printf("held %d\n", r);
    held.unlock();
    std::thread p2([&] { r = held.try_lock(); if (r) held.unlock(); });
    p2.join();
    std::printf("free %d\n", r);
    return 0;
}

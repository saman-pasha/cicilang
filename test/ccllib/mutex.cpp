// the twin of mutex.c over std::mutex, std::lock_guard, std::unique_lock, std::latch and std::barrier (phase 2):
// clang++ builds it over libc++ and it prints mutex.expect
#include <atomic>
#include <barrier>
#include <cstdio>
#include <latch>
#include <mutex>

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
    return 0;
}

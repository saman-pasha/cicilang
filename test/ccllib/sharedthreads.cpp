// the twin of sharedthreads.c over std::shared_ptr, std::weak_ptr and std::thread (1.6.5): clang++ builds it over
// libc++, and it prints sharedthreads.expect
#include <cstdio>
#include <memory>
#include <thread>
static long work(std::shared_ptr<long> *p) {
    long sum = 0;
    int bad = 0;
    for (int i = 0; i < 20000; i++) {
        std::shared_ptr<long> c = *p;
        sum += *c;
        if (c.use_count() < 2) bad++;
        std::weak_ptr<long> w = c;
        std::shared_ptr<long> l = w.lock();
        if (l.get() == nullptr || w.expired()) bad++;
        l.reset();
        std::shared_ptr<long> mine = std::make_shared<long>(i);
        sum += *mine - i;
    }
    return sum == 20000L * 3 && bad == 0 ? 1 : 0;
}
int main() {
    std::shared_ptr<long> p = std::make_shared<long>(3L);
    long r[4];
    std::thread t[4];
    for (int k = 0; k < 4; k++) t[k] = std::thread([&r, &p, k] { r[k] = work(&p); });
    int ok = 0;
    for (int k = 0; k < 4; k++) { t[k].join(); ok += (int)r[k]; }
    std::printf("threads %d count %d value %ld\n", ok, (int)p.use_count(), *p);
    return 0;
}

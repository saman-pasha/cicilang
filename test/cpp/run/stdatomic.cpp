#include <atomic>
#include <cstdio>
std::atomic<int> g{5};
int main() {
    std::atomic<int> a{0};
    ++a; a += 2; a.fetch_add(3); a.store(a.load() * 2);
    int old = a.exchange(7);
    int e = 7; bool ok = a.compare_exchange_strong(e, 9);
    std::atomic<long> l{10}; l--; l.fetch_sub(2);
    std::atomic<bool> b{false}; b = true;
    g.fetch_add(1);
    printf("%d %d %d %ld %d %d\n", a.load(), old, (int) ok, l.load(), (int) b.load(), g.load());
    return 0;
}

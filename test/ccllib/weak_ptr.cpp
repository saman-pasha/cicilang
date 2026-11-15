// the twin of weak_ptr.c over std::weak_ptr (1.1.5): clang++ builds it over libc++, and it prints weak_ptr.expect, the
// lines that the C build and the C++ build of weak_ptr.c print
#include <cstdio>
#include <memory>
int main() {
    std::shared_ptr<int> p = std::make_shared<int>(5);
    std::weak_ptr<int> w = p;
    std::weak_ptr<int> c = w;
    std::shared_ptr<int> q = w.lock();
    std::printf("lock: %d %d %zu %zu\n", w.expired(), *q, w.use_count(), p.use_count());
    std::shared_ptr<int> r = p;
    std::printf("clone: %zu %zu\n", w.use_count(), r.use_count());
    p.reset();
    std::printf("reset p: %d %zu\n", w.expired(), w.use_count());
    q.reset();
    std::printf("reset q: %d %zu\n", w.expired(), w.use_count());
    r.reset();
    std::printf("reset r: %d\n", w.expired());
    std::shared_ptr<int> none = w.lock();
    std::printf("lock after: %d %d\n", w.expired(), none.get() == nullptr);
    c.reset();
    std::weak_ptr<int> e;
    std::printf("empty: %d %d\n", e.expired(), e.lock().get() == nullptr);
    return 0;
}

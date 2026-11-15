/* <memory.pl>'s weak_ptr (1.1.5; CCLLIB.md's phase 1b): a weak_ptr born from a shared_ptr, clone as a second weak
   handle, lock as a shared owner, expired, use_count, reset, and the empty weak_ptr; the shared handle it watches is
   moved, reset and cloned. cicilang builds this file as C and cicilang++ as C++; weak_ptr.cpp is its twin over
   std::weak_ptr, which clang++ builds over libc++: the three print the same lines, weak_ptr.expect. */
#include <stdio.h>
#include <memory.pl>
int main(void) {
    shared_ptr<int> p = make_shared<int>(5);
    weak_ptr<int> w = p;
    weak_ptr<int> c = clone(w);
    shared_ptr<int> q = lock(w);
    printf("lock: %d %d %zu %zu\n", expired(w), *q, use_count(w), use_count(p));
    shared_ptr<int> r = clone(p);
    printf("clone: %zu %zu\n", use_count(w), use_count(r));
    reset(p);
    printf("reset p: %d %zu\n", expired(w), use_count(w));
    reset(q);
    printf("reset q: %d %zu\n", expired(w), use_count(w));
    reset(r);
    printf("reset r: %d\n", expired(w));
    shared_ptr<int> none = lock(w);
    printf("lock after: %d %d\n", expired(w), get(none) == 0);
    reset(c);
    weak_ptr<int> e;
    shared_ptr<int> le = lock(e);
    printf("empty: %d %d\n", expired(e), get(le) == 0);
    return 0;
}

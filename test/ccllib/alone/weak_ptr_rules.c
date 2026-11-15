/* THE RULES OF A WEAK_PTR of <memory.pl> (1.1.5), checked from outside: a weak_ptr observes a shared_ptr's block -- its
   expired is `the strong count is zero', its use_count is the strong count, lock of a live block gives one more shared
   owner and lock of an expired one gives an empty shared_ptr, clone gives another weak handle of the same block, reset
   empties it, and swap exchanges two -- over a walk of chance of 4000 steps on two shared_ptrs and two weak_ptrs: a
   make of either, a clone of either, a reset of either, a clone and a reset of either weak, a lock and a swap. After
   each step each weak is held to the two counts, and its lock is held to the strong count. cicilang builds this file as
   C and cicilang++ as C++; both print weak_ptr_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <memory.pl>
static long checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static void is(long long got, long long want, const char *what) { checks++; if (got != want) no(what); }
static void held(const weak_ptr<int> *w) {
    size_t n = use_count(*w);
    is(expired(*w), n == 0, "expired is the strong count's zero");
    shared_ptr<int> l = lock(*w);
    if (n == 0) is(get(l) == 0, 1, "lock of an expired weak_ptr is empty");
    else { is(get(l) != 0, 1, "lock of a live weak_ptr holds the object"); is(use_count(l), n + 1, "lock adds one strong owner"); }
}
int main(void) {
    shared_ptr<int> s, t;
    weak_ptr<int> w1, w2;
    unsigned x = 2024;
    for (int step = 0; step < 4000; step++) {
        x = x * 1103515245u + 12345u;
        int k = (int)(x >> 12 & 0x3ff);
        switch ((x >> 28) % 10) {
        case 0: s = make_shared<int>(k); break;
        case 1: t = make_shared<int>(k); break;
        case 2: t = clone(s); break;
        case 3: s = clone(t); break;
        case 4: reset(s); break;
        case 5: reset(t); break;
        case 6: { weak_ptr<int> n = s; swap(w1, n); break; }
        case 7: { weak_ptr<int> n = t; swap(w2, n); break; }
        case 8: { weak_ptr<int> c = clone(w1); w1 = c; break; }
        default: swap(w1, w2); break;
        }
        held(&w1);
        held(&w2);
    }
    /* a weak outlives its shared owner, and reset of the weak is the end */
    shared_ptr<int> p = make_shared<int>(8);
    weak_ptr<int> w = p;
    reset(p);
    is(expired(w), 1, "a weak outlives its shared owner");
    reset(w);
    is(expired(w), 1, "reset of a weak empties it");
    swap(w1, w2);
    weak_ptr<int> e;
    shared_ptr<int> le = lock(e);
    is(get(le) == 0, 1, "lock of an empty weak is empty");
    is(expired(e), 1, "an empty weak is expired");
    printf("the rules held at %ld checks, over a walk of chance of 4000 steps on two shared and two weak pointers\n", checks);
    return 0;
}

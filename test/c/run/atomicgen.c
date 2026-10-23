/* GCC's generic atomic builtins (0.194): `__atomic_load', `__atomic_store', `__atomic_exchange' and
   `__atomic_compare_exchange' move an object of any type through pointers -- an int, a long, a char, a double, a pointer
   and a struct of eight bytes aligned to eight, each moved as the integer of its size -- the memory order a constant or a
   variable, the weak form in a loop. libc++ 21's atomic_ref is written on them; they were undeclared. */
#include <stdbool.h>
#include <stdio.h>
struct P { _Alignas(8) int a; int b; };
int main(void) {
    int x = 5, r = 0, v = 9, e = 9, d = 11, old = 0, mo = __ATOMIC_ACQUIRE;
    __atomic_load(&x, &r, __ATOMIC_SEQ_CST);
    __atomic_store(&x, &v, __ATOMIC_RELEASE);
    __atomic_exchange(&x, &d, &old, __ATOMIC_ACQ_REL);
    bool ok1 = __atomic_compare_exchange(&x, &e, &v, false, __ATOMIC_SEQ_CST, __ATOMIC_RELAXED);
    bool ok2 = __atomic_compare_exchange(&x, &e, &v, false, __ATOMIC_SEQ_CST, __ATOMIC_RELAXED);
    int r2 = 0;
    __atomic_load(&x, &r2, mo);
    printf("%d %d %d %d %d %d %d\n", r, old, (int) ok1, e, (int) ok2, x, r2);
    long lx = 1L << 40, lr = 0, lv = -3;
    __atomic_exchange(&lx, &lv, &lr, __ATOMIC_SEQ_CST);
    char cx = 'a', cr = 0, cv = 'z';
    __atomic_store(&cx, &cv, __ATOMIC_SEQ_CST);
    __atomic_load(&cx, &cr, __ATOMIC_RELAXED);
    double dx = 1.5, dr = 0, dv = -2.25;
    __atomic_exchange(&dx, &dv, &dr, __ATOMIC_SEQ_CST);
    int *px = &x, *pr = 0, *pv = &r;
    __atomic_exchange(&px, &pv, &pr, __ATOMIC_SEQ_CST);
    printf("%ld %ld %c %g %g %d %d\n", lx, lr, cr, dx, dr, pr == &x, px == &r);
    struct P p = {1, 2}, q = {0, 0}, n = {3, 4}, ex = {1, 2};
    __atomic_load(&p, &q, __ATOMIC_SEQ_CST);
    while (!__atomic_compare_exchange(&p, &ex, &n, true, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE))
        ;
    struct P o = {0, 0}, m = {7, 8};
    __atomic_exchange(&p, &m, &o, __ATOMIC_SEQ_CST);
    printf("%d %d %d %d %d %d %d %d %zu %zu\n", q.a, q.b, o.a, o.b, p.a, p.b, ex.a, ex.b, sizeof(struct P), _Alignof(struct P));
    return x;
}

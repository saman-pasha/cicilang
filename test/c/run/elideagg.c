/* BRACE ELISION INTO AN ARRAY MEMBER WHOSE ELEMENTS ARE RECORDS OR ARRAYS (C17 6.7.9/20; 0.285): a scalar given to
   such a member begins its first element, and the member takes the items that its elements need, each in turn. `{0}'
   is every aggregate's zero: `struct S s = {0};' over a member `struct P a[2]' reached LLVM as a cast of an int to an
   array, and a flat list over `int m[2][2]' gave the member two items and the next member the third. A local's and a
   static's; an element given a value of its own type stays that value. It prints what clang's build prints */
#include <stdio.h>
struct P { int x, y; };
struct S { struct P a[2]; int n; };
struct T { struct S s[2][3]; double d; };
struct U { int m[2][2]; int k; };
struct V { struct U u[2]; char c; };
static struct S gs = {0};
static struct S g5 = {1, 2, 3, 4, 5};
static struct U gu = {1, 2, 3, 4, 5};
static struct V gv = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 'c'};
int main(void) {
    struct S s = {0};
    struct T t = {0};
    struct P q[3] = {0};
    struct S f = {1, 2, 3, 4, 5};
    struct U u = {1, 2, 3, 4, 5};
    struct V v = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 'c'};
    struct P p0 = {7, 8};
    struct S w = {{p0, p0}, 9};
    struct S part = {1, 2, 3};
    printf("%d %d %d %d %d\n", s.a[0].x, s.a[1].y, s.n, gs.a[1].x, gs.n);
    printf("%d %g %d\n", t.s[1][2].a[1].y, t.d, q[2].y);
    printf("%d %d %d %d %d | ", f.a[0].x, f.a[0].y, f.a[1].x, f.a[1].y, f.n);
    printf("%d %d %d %d %d\n", g5.a[0].x, g5.a[0].y, g5.a[1].x, g5.a[1].y, g5.n);
    printf("%d %d %d %d %d | ", u.m[0][0], u.m[0][1], u.m[1][0], u.m[1][1], u.k);
    printf("%d %d %d %d %d\n", gu.m[0][0], gu.m[0][1], gu.m[1][0], gu.m[1][1], gu.k);
    printf("%d %d %d %d %c | ", v.u[0].m[1][1], v.u[0].k, v.u[1].m[0][0], v.u[1].k, v.c);
    printf("%d %d %d %d %c\n", gv.u[0].m[1][1], gv.u[0].k, gv.u[1].m[0][0], gv.u[1].k, gv.c);
    printf("%d %d %d %d %d\n", w.a[0].x, w.a[1].y, w.n, part.a[1].x, part.a[1].y + part.n);
    return 0;
}

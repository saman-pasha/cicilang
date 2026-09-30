/* designated initializers, global and local, through anonymous members; offsetof (0.108) */
#include <stdio.h>
struct P { int x, y; };
struct R { int a; struct P p; int arr[3]; };
union U { int i; double d; char c[8]; };
struct Q { int a; union { int u; float f; }; struct { char p, q; }; };
int arr[] = { [3] = 7, [1] = 2 };
int arr2[6] = { 1, [4] = 9, 10 };
struct P pts[3] = { [1] = { .x = 5 }, [2].y = 8 };
struct R r = { .p.y = 4, .arr[1] = 6, .a = 1 };
union U u1 = { .d = 2.5 };
struct Q qg = { .u = 3, .q = 'z' };

#include <stddef.h>
struct OP { char c; int x; double d; int arr[4]; struct { short s; long l; } in; };
static char obuf[offsetof(struct OP, d)];
static void offsets(void) {
    printf("%zu %zu %zu %zu\n", offsetof(struct OP, x), offsetof(struct OP, d), offsetof(struct OP, arr[2]), offsetof(struct OP, in.l));
    printf("%zu %zu %zu %zu\n", offsetof(struct Q, u), offsetof(struct Q, f), offsetof(struct Q, q), sizeof obuf);
    struct Q qq; qq.a = 1; qq.u = 7; qq.p = 'x'; qq.q = 'y';
    printf("%d %d %c %c %zu\n", qq.a, qq.u, qq.p, qq.q, sizeof qq);
    qq.f = 1.5f; printf("%.1f\n", qq.f);
}
int main(void) {
    offsets();
    printf("%zu %d %d %d %d\n", sizeof arr / sizeof arr[0], arr[0], arr[1], arr[2], arr[3]);
    for (int i = 0; i < 6; i++) printf("%d ", arr2[i]); printf("\n");
    for (int i = 0; i < 3; i++) printf("(%d,%d) ", pts[i].x, pts[i].y); printf("\n");
    printf("%d %d %d %d %d %d\n", r.a, r.p.x, r.p.y, r.arr[0], r.arr[1], r.arr[2]);
    printf("%.1f %d %d %c\n", u1.d, qg.a, qg.u, qg.q);
    struct R lr = { .p.y = 4, .arr[1] = 6, .a = 1 };
    printf("%d %d %d %d %d %d\n", lr.a, lr.p.x, lr.p.y, lr.arr[0], lr.arr[1], lr.arr[2]);
    struct Q ql = { .u = 3, .q = 'z' };
    printf("%d %d %d\n", ql.a, ql.u, ql.q);
    int la[] = { [2] = 5, [0] = 1 };
    printf("%zu %d %d %d\n", sizeof la / sizeof la[0], la[0], la[1], la[2]);
    return 0;
}

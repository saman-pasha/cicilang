/* THE GNU `cleanup' ATTRIBUTE (1.6.8): the function runs with the object's address where the object's scope ends --
   at the block's end, a return after its value, break, continue, a goto out of the scope and back over the object,
   a statement expression's end, a for's declaration at the loop's end, each iteration's own -- the last declared
   first; the specifiers' attribute is each declarator's; __cleanup__ and C23's [[gnu::cleanup(f)]] alike; an object
   with no initializer, a register one, a const one with an `int *' parameter, a `void *' parameter, a struct, a
   typedef's, a function whose result is dropped */
#include <stdio.h>
static void bye(int *p) { printf("bye %d\n", *p); }
static void inc(int *p) { printf("sees %d\n", *p); *p += 100; }
static int ret_ignored(int *p) { printf("ret %d\n", *p); return 9; }
static void byev(void *p) { printf("void %d\n", *(int *)p); }
struct res { int id; int open; };
typedef struct res res_t;
static void close_res(struct res *r) { printf("close %d %d\n", r->id, r->open); r->open = 0; }
static int f(void) { int x __attribute__((cleanup(inc))) = 1; return x; }
static int g(int k) { int y __attribute__((cleanup(inc))) = k; if (k > 1) return y * 2; y = 7; return y; }
static void loops(void) {
    for (int i = 0; i < 4; i++) {
        int v __attribute__((cleanup(bye))) = i;
        if (i == 1) continue;
        if (i == 3) break;
        printf("body %d\n", v);
    }
    int n = 0;
again:
    {
        int w __attribute__((cleanup(bye))) = 10 + n;
        if (n++ < 2) goto again;
        if (n == 3) goto out;
        printf("not here\n");
    }
out:
    printf("out %d\n", n);
    switch (n) { case 3: { int s __attribute__((cleanup(bye))) = 30; printf("case\n"); break; } default: break; }
    while (n < 5) { int t __attribute__((cleanup(bye))) = 40 + n; n++; }
    do { int u __attribute__((cleanup(bye))) = 50; } while (0);
}
static void back(void) {
    int n = 0;
again:;
    int v __attribute__((cleanup(bye))) = n;
    if (++n < 3) goto again;
    printf("end %d\n", v);
}
static void kinds(void) {
    int a __attribute__((__cleanup__(bye))) = 1;
    __attribute__((cleanup(bye))) int b = 2, c = 3;
    int d __attribute__((unused, cleanup(bye))) = 4, e = 5;
    int r __attribute__((cleanup(ret_ignored))) = 6;
    const int k __attribute__((cleanup(bye))) = 7;
    register int q __attribute__((cleanup(bye))) = 8;
    int z __attribute__((cleanup(byev))) = 9;
    int none __attribute__((cleanup(bye)));
    none = 10;
    struct res s1 __attribute__((cleanup(close_res))) = { 1, 1 };
    res_t s2 __attribute__((cleanup(close_res))) = { .id = 2, .open = 1 };
    printf("%d %d %d %d %d %d %d %d %d %d %d %d\n", a, b, c, d, e, r, k, q, z, none, s1.id, s2.id);
}
static void exprs(void) {
    int r = ({ int t __attribute__((cleanup(bye))) = 5; t * 2; });
    for (int i __attribute__((cleanup(bye))) = 0; i < 2; i++) printf("i %d\n", i);
    { int inner __attribute__((cleanup(bye))) = 60; printf("inner\n"); }
    printf("r %d\n", r);
}
int main(void) {
    printf("%d\n", f());
    printf("%d\n", g(5));
    printf("%d\n", g(0));
    loops();
    back();
    kinds();
    exprs();
    printf("has %d %d %d\n", __has_attribute(cleanup), __has_attribute(__constructor__), __has_attribute(destructor));   /* the three that the reader honours */
    return 0;
}

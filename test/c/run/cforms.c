/* C forms the probes found missing (0.108): an array compound literal, _Bool's conversion, a K&R definition,
   [static N], __func__, an enum in a block, an array member used as a pointer and passed on, tentative
   definitions, assert, #line */
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
int t;
int t;
int t1;
int t1 = 3;
extern int t2;
int t2 = 4;
struct N { char name[16]; int v; };
static struct N g = { "global", 1 };
static int sum3(const int *a) { return a[0] + a[1] + a[2]; }
int add(a, b) int a; int b; { return a + b; }
double halve(x) double x; { return x / 2; }
long count(p, n) char *p; int n; { long k = 0; while (n-- > 0) if (*p++ == 'a') k++; return k; }
static int first(int a[static 3]) { return a[0] + a[2]; }
static int second(int a[const 2]) { return a[1]; }
int main(void) {
    int *p = (int[]){4, 5, 6};
    printf("%d %d %zu\n", p[1], sum3((int[]){1, 2, 3}), sizeof((int[]){1, 2, 3, 4}) / sizeof(int));
    _Bool b = 42; bool c = 0.5; _Bool d = (void *) 0; int x = 7; _Bool e = x;
    printf("%d %d %d %d\n", b, c, d, e);
    printf("%d %.1f %ld\n", add(2, 3), halve(5.0), count("banana", 6));
    int v[3] = {1, 2, 3};
    printf("%d %d %s\n", first(v), second(v), __func__);
    enum color { RED, GREEN = 5, BLUE };
    enum color col = BLUE;
    printf("%d %d %d\n", col, GREEN, RED);
    struct { char s[8]; int n; } a = { "abc", 3 };
    struct N nb; strcpy(nb.name, "bee"); nb.v = 2;
    printf("%s %d %s %d %s %zu %c\n", a.s, a.n, nb.name, nb.v, g.name, strlen(a.s), a.s[1]);
    char *q = a.s; printf("%c\n", q[2]);
    t = 2; printf("%d %d %d\n", t, t1, t2);
    assert(nb.v == 2);
#line 100 "other.c"
    printf("%d %s\n", __LINE__, __FILE__);
    return 0;
}

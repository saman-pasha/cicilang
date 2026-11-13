/* Names declared before their use, which C takes (1.1.2): each name here is declared where it is used, though a
   declaration at file scope of the same name, or of the name's own entity, comes later -- recursion, a prototype before
   a mutual recursion and a table of the two, a block's own declaration of a function defined further down, a parameter
   and a local over a later global's name, a member, a designator and a label of a later global's name, offsetof's
   member, a case's enumerator, a := local over a later global's name, _Generic over functions defined before it, an
   extern declaration before its definition, a builtin, __func__, the global macros, an instance's call by name before a
   later function of the program of that name, a header's enumerators, and the names of one declaration or one parameter
   list, each in scope just after its declarator -- in its own initializer, in a later declarator's, in a later
   parameter's bound, a prototype's and a definition's -- where a later declaration at file scope names them too */
#include <stdio.h>
#include <stddef.h>
#include <deque.pl>
#include "declorder.h"

struct rec { int a; int len; };
enum color { RED, GREEN, BLUE };

static int fact(int n) { return n ? n * fact(n - 1) : 1; }
static int odd(int n);
static int even(int n) { return n == 0 ? 1 : odd(n - 1); }
static int odd(int n) { return n == 0 ? 0 : even(n - 1); }
static int (*table[])(int) = { even, odd };
static int via_block(void) { extern int twice(int); return twice(4); }
static int by_param(int len) { return len; }
static int by_local(void) { int len = 7; return len; }
static int by_member(struct rec *p) { return p->len + (*p).len; }
static size_t by_offset(void) { return offsetof(struct rec, len); }
static int by_label(int x) { if (x) goto out; x = 5; out: return x; }
static int by_case(enum color c) { switch (c) { case RED: return 1; case GREEN: return 2; default: return 3; } }
static int by_walrus(void) { len2 := 3; return len2 + 1; }
static int fi(int x) { return x + 1; }
static double fd(double x) { return x * 2; }
#define GEN(x) _Generic((x), int: fi, double: fd)(x)
extern int counter;
static int read_counter(void) { return counter; }
static int count_of(void) { deque<int> d; push_back(d, 1); push_back(d, 2); push_back(d, 3); return (int)size(d); }
static int one_decl(void) { int len = 1, k = len + 1, z = sizeof z; return k + z; }
static int one_for(void) { int s = 0; for (int out = 1, j = out; j < 3; j++) s += out + j; return s; }
static int one_vla(void) { int counter = 2, arr[counter]; arr[0] = counter; arr[1] = 1; return arr[0] + arr[1]; }
static int bound_sum(int len2, int a[len2]);
static int lead(int out, int a[out]) { return a[0] + out; }
int px0 = 4, *pxp = &px0, sz0 = sizeof sz0;

int twice(int x) { return 2 * x; }
int len = 11;
int len2 = 12;
int out = 13;
int counter = 14;
static int size(int x) { return x + 100; }
static int sized(void) { return size(1); }
static int bound_sum(int n, int a[n]) { int t = 0; for (int i = 0; i < n; i++) t += a[i]; return t; }

int main(void) {
    struct rec r = { .a = 1, .len = 2 };
    printf("%d %d %d %d %d\n", fact(5), even(10), odd(7), table[0](4), table[1](4));
    printf("%d %d %d %d %zu\n", via_block(), by_param(1), by_local(), by_member(&r), by_offset());
    printf("%d %d %d %d %.1f\n", by_label(0), by_case(BLUE), by_walrus(), GEN(1), GEN(1.5));
    printf("%d %d %d %d %d %s\n", read_counter(), len, len2, out, __builtin_popcount(7u), __func__);
    println("{} {} {} {}", len, counter, count_of(), sized());
    int pair[2] = { 5, 6 };
    printf("%d %d %d %d %d %d %d %d\n", DARK + LIGHT, one_decl(), one_for(), one_vla(), bound_sum(2, pair), *pxp, sz0, lead(2, pair));
    return 0;
}

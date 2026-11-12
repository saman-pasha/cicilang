/* A FUNCTION WHOSE EVERY RETURN IS STATIC STORAGE ANSWERS NO NEW MEMORY (0.294): a pointer into a static table, a
   string literal, a global's address, a pointer that a global's plain slot holds, a static local's array, a null,
   the C library's static storage, a conditional of two such, and a call of another such function -- two that call
   each other too. Each call was new memory to the safe part, and the plain local that took it `plain pointer not
   consumed'. clang's build prints what cicilang's prints, in C and as C++ */
#include <stdio.h>
#include <stdlib.h>
static const int table[4] = { 1, 2, 3, 4 };
static const char *names[3] = { "zero", "one", "two" };
static int counter;
struct cfg { const char *name; int level; };
static struct cfg gcfg = { "cfg", 3 };
static const int *row(int i) { return table + i; }
static const int *row_at(int i) { return &table[i]; }
static const char *greet(void) { return "hello"; }
static int *counter_addr(void) { return &counter; }
static const int *row_or_null(int i) { return i < 4 ? table + i : NULL; }
static const int *row_pick(int i) { if (i % 2) return &table[i]; return table; }
static const int *row2(int i) { return row(i); }
static const char *name_of(int i) { return names[i]; }
static const char *cfg_name(void) { return gcfg.name; }
static char *scratch(void) { static char sbuf[16] = "static buf"; return sbuf; }
static const char *env_x(void) { return getenv("CICILANG_PROBE_UNSET"); }
static const int *pong(int i);
static const int *ping(int i) { return i ? pong(i - 1) : table + 1; }
static const int *pong(int i) { return i ? ping(i - 1) : table + 2; }
int main(void) {
    const int *p = row(2);
    const int *q = row_at(1);
    const char *g = greet();
    int *c = counter_addr();
    *c = 5;
    const int *n = row_or_null(9);
    const int *k = row_pick(3);
    const int *r2 = row2(0);
    const char *nm = name_of(2);
    const char *cn = cfg_name();
    char *s = scratch();
    const char *e = env_x();
    const int *pp = ping(3);
    printf("%d %d %s %d %s %d %d %s %s %s %s %d\n", *p, *q, g, counter, n ? "set" : "null", *k, *r2, nm, cn, s, e ? e : "unset", *pp);
    return 0;
}

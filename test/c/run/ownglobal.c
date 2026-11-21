/* THE GLOBAL MACROS YIELD (1.6.9, the owner's rule: "Yes user implemented should win over ccllib's macros"): a
   program's own format, print, println and clone are its own -- functions of its file, one that a header of its own
   declares and the file defines further down, a local and a parameter that hide them -- and clang's build of this
   file prints the same lines; through 1.6.8 each was the global macro's, or refused in the macro's words */
#include <stdio.h>
#include "ownglobal.h"
struct pt { int x, y; };
static void println(const char *s) { printf("mine: %s\n", s); }
static const char *format(int n) { return n > 1 ? "many" : "one"; }
static struct pt clone(struct pt p) { p.x += 10; return p; }
static void run(int (*println)(const char *)) { println("through a parameter"); }
int main(void) {
    println("hi");
    int r = print(2, 3);
    printf("%d %s %s\n", r, format(1), format(5));
    struct pt a = { 1, 2 }, b = clone(a);
    printf("%d %d %d\n", a.x, b.x, b.y);
    {
        int (*format)(const char *) = puts;
        format("through a local");
    }
    printf("%s\n", format(2));
    run(puts);
    return 0;
}
int print(int a, int b) { printf("sum %d\n", a + b); return a + b; }

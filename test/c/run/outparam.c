/* A POINTER VALUE THAT HOLDS NO MEMORY THE CHECK FOLLOWS IS NO NEW MEMORY (0.299): a pointer that a call wrote through
   an out-parameter -- the end of strtod, strtol, strtoul, strtof and strtold -- copied, moved by an integer, assigned,
   walked in a loop and stored in a local struct's field, and a null local moved by one. Each was `plain pointer not
   consumed' (the Ambitious session's finding 29), and the struct's field `no owner behind'. And such a pointer stored
   where it outlives the function -- a global, the pointee of a parameter, a parameter's struct -- as a value that a
   plain slot held is (0.290); each was `no owner behind' */
#include <stdio.h>
#include <stdlib.h>
struct cursor { const char *at; };
static int tail(const char *s) { char *end = 0; (void)strtod(s, &end); char *rest = end + 2; return *rest ? 1 : 0; }
static long num(const char *s, int *unit) {
    char *end = 0; long v = strtol(s, &end, 10); const char *rest = end + 1; *unit = *rest; return v;
}
static int copy(const char *s) { char *end = 0; (void)strtoul(s, &end, 10); char *rest = end; return *rest; }
static int assigned(const char *s) { char *end = 0; char *rest; (void)strtof(s, &end); rest = end + 2; return *rest; }
static int walk(const char *s) {
    char *end = 0; (void)strtold(s, &end); char *p = end; while (*p == ' ') p++; return *p;
}
static int field(const char *s) { char *end = 0; struct cursor c; (void)strtod(s, &end); c.at = end + 1; return *c.at; }
static int nulllocal(void) { char *end = 0; char *rest = end + 1; return rest != 0; }
static const char *gend;
static int global(const char *s) { char *end = 0; (void)strtod(s, &end); gend = end + 1; return *gend; }
static double numrest(const char *s, char **rest) { char *end = 0; double d = strtod(s, &end); *rest = end; return d; }
static void adv(struct cursor *c, const char *s) { char *end = 0; (void)strtol(s, &end, 10); c->at = end; }
int main(void) {
    int unit = 0;
    long v = num("42pt", &unit);
    printf("%d %ld %c %c %c %c %c %d\n", tail("12px"), v, unit, copy("7q"), assigned("3.5emx"), walk("9   z"),
           field("1ab"), nulllocal());
    char *r = 0;
    double d = numrest("12px", &r);
    struct cursor cur = {0};
    adv(&cur, "42z");
    printf("%c %g %c %c\n", global("1ab"), d, *r, *cur.at);
    return 0;
}

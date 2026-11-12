/* STATIC ROWS (0.297): a row of a static array, a row of a row, the first row through `*', an array member of a static
   struct and a row of a static local's array, each used as a pointer, are static storage -- a borrow that nothing ends:
   read, handed to a function and returned by one, as clang builds them (the Ambitious session's finding 15, extended:
   `const unsigned char *row = table[argc & 1];') */
#include <stdio.h>
static const unsigned char table[2][3] = { { 1, 2, 3 }, { 4, 5, 6 } };
static const char words[2][2][4] = { { "ab", "cd" }, { "ef", "gh" } };
static struct { char name[8]; int n; } cfg = { "abc", 3 };
static const unsigned char *rowof(int i) { return table[i]; }
static int sum3(const unsigned char *r) { return r[0] + r[1] + r[2]; }
int main(int argc, char **argv) {
    (void)argv;
    const unsigned char *row = table[argc & 1];
    const char *w = words[argc & 1][1];
    const unsigned char *first = *table;
    const unsigned char *r2 = rowof(0);
    const char *p = cfg.name;
    static const int t[2][2] = { { 1, 2 }, { 3, 4 } };
    const int *tr = t[argc & 1];
    printf("%d %s %d %d %d %s %d %d\n", row[0], w, first[2], sum3(r2), sum3(table[1]), p, cfg.n, tr[1]);
    return 0;
}

/* C's values that are no lvalues (1.6.13; C17 6.5.2.3/3, 6.5.15, 6.5.16/3, 6.5.17): a member of a conditional, of a comma
   and of a call's value is read from the value, and an assignment's, a step's and a comma's values are values. An
   assignment to one, a step of one and its address are refused in clang's words (test/driver.sh). Through 1.6.12
   `(g(), s2).m' was refused by name, `lvalue(comma(...))', and `(c ? a : b) = 5' was taken */
#include <stdio.h>
int a = 1, b = 2;
int g(void) { return 0; }
struct S { int m; struct { int k; } in; } s1 = { 1, { 10 } }, s2 = { 2, { 20 } };
struct S h(void) { return s1; }
int main(int argc, char **argv) {
    (void)argv;
    int v1 = (argc > 0 ? s1 : s2).m;
    int v2 = (g(), s2).m;
    int v3 = h().m + (g(), s1).in.k + (argc > 0 ? s2 : s1).in.k;
    int x = (argc > 0 ? a : b);
    x += (g(), b);
    int y = (a = 4) + (++b);
    int z = (a++, b--, a + b);
    printf("%d %d %d %d %d %d %d %d\n", v1, v2, v3, x, y, z, a, b);
    return 0;
}

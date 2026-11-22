/* The forms that 1.6.14's rules keep: a void value where no value is taken -- a cast to void, the left operand of a
 * comma, a conditional's arm, GNU's conditional of one void arm, a void function's return of one, sizeof of one (GNU's
 * 1, and of a function too, in a constant expression as in a value, and of a conditional with either arm void) -- and the forms beside its operand rules that C takes: a subscript with the integer first,
 * a switch over a character, a _Bool and an enumeration, an enumeration that a declaration defines with its declarator,
 * and a function that a block declares; and GNU's casts beside a void operand's, a struct to its own type and a value to a
 * union that has its type. Through 1.6.13 `2[a]' was refused by name, `sizeof(f)' was 8 and `enum e { A, B } v = B;' was
 * `use of undeclared identifier 'B'' */
#include <stdio.h>
int z;
void f(void) { z++; }
void h(void) { return f(); }
int twice(int v) { return v * 2; }
static enum st { IDLE, RUN = IDLE + 2 } state = RUN;
struct S0 { int m; }; union U0 { int i; char c; };
int main(void) {
    int a[3] = { 4, 5, 6 };
    (void)f(); f(), f(); z ? f() : (void)0; h();
    printf("calls: %d\n", z);
    z = 0 ? (f(), 1) : 2;
    printf("subscripts: %d %d %c\n", 1[a], *(a + 2), 2["xyz"]);
    printf("sizes: %zu %zu %zu %zu %zu\n", sizeof(f()), sizeof(f), sizeof(void), sizeof(z ? f() : 1), sizeof(z ? 1 : f()));
    char fa[sizeof(f)], fb[sizeof(void (void))], fc[sizeof(f())];
    printf("constant sizes: %zu %zu %zu\n", sizeof fa, sizeof fb, sizeof fc);
    enum e { A, B } v = B;
    switch (v) { case B: printf("enumeration B, state %d\n", (int)state); break; default: break; }
    { int twice(int); printf("block's function: %d\n", twice(21)); }
    switch ((char)1) { case 1: printf("char\n"); break; default: break; }
    _Bool b = 1;
    switch (b) { case 1: printf("bool\n"); break; default: break; }
    z = 1; z ? f() : 1; printf("one void arm: %d\n", z);
    z = 0; z ? 1 : f(); printf("the other: %d\n", z);
    struct S0 s0 = { 7 }; struct S0 t0 = (struct S0)s0; const struct S0 w0 = (const struct S0)s0; union U0 v0 = (union U0)9;
    printf("casts: %d %d %d\n", t0.m, w0.m, v0.i);
    return 0;
}

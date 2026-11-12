/* A CONDITIONAL WHOSE ARMS ARE ARRAYS (0.294): its arms decay, an array to a pointer to its first element and a
   function to a pointer to it (C17 6.5.15/3 by 6.3.2.1/3 and /4). The array's own type was the conditional's, and
   `c ? buf : "none"' over `char buf[8]' was LLVM's `invalid cast opcode for cast from 'ptr' to '[8 x i8]'', and `c ? 0
   : buf' a cast from 'i32'. Each arm in each place: a local, a global, a member, a const array, two arrays of two
   lengths, a literal on either side, a null, functions, a call's argument and a variadic one, and `sizeof' of one, a
   pointer's bytes. clang's build prints what cicilang's prints, in C and as C++ */
#include <stdio.h>
#include <string.h>
struct rec { char name[8]; int n; };
static char gbuf[8] = "glob";
static int inc(int x) { return x + 1; }
static int dec(int x) { return x - 1; }
static int flag(int k) { return k; }   /* the arms chosen as the gates run it, with arguments or none */
int main(void) {
    int c = flag(0), d = flag(1);
    char buf[8] = "abc";
    char big[16] = "a longer one";
    const char cbuf[] = "xyz";
    struct rec r = { "mem", 1 };
    const char *p1 = c ? buf : "none";
    const char *p2 = d ? buf : "none";
    const char *p3 = c ? "none" : buf;
    const char *p4 = d ? big : buf;
    const char *p5 = c ? cbuf : "none";
    const char *p6 = d ? gbuf : "none";
    const char *p7 = d ? r.name : "none";
    const char *p8 = c ? 0 : buf;
    const char *p9 = d ? buf : NULL;
    int (*f)(int) = d ? inc : dec;
    int a[3] = { 1, 2, 3 }, b[2] = { 4, 5 };
    int *q = c ? a : b;
    printf("%s %s %s %s %s %s %s %s %s\n", p1, p2, p3, p4, p5, p6, p7, p8 ? p8 : "(null)", p9 ? p9 : "(null)");
    printf("%d %d %zu %zu %zu\n", f(10), q[0], sizeof(d ? buf : "none"), sizeof(d ? big : "none"), strlen(d ? big : buf));
    puts(d ? buf : "none");
    printf("%s\n", c ? cbuf : r.name);
    return 0;
}

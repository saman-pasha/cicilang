/* borrows of an object whose name a block declares again (1.6.33): the outer object's borrow kept over the block,
   used inside it and after it -- an int, a name declared again twice, a loop's body left by a break, an array that
   each block uses as a pointer, two blocks one after the other, a struct's member -- each was `use of a borrow after
   its owner was consumed', and the inner object's borrows end with their block as before */
#include <stdio.h>
struct pt { int a, b; };
static int twice(void) {
    int x = 1; int *p = &x;
    { int x = 2; int *q = &x; { int x = 3; int *r = &x; printf("%d %d %d\n", *p, *q, *r); } printf("%d %d\n", *p, *q); }
    return *p;
}
static int broken(void) {
    int x = 10; int *p = &x;
    for (int i = 0; i < 3; i++) { int x = i; int *q = &x; if (*q == 1) break; }
    return *p;
}
static int arrays(void) {
    int a[2] = { 5, 6 }; int *p = a;
    { int a[2] = { 7, 8 }; int *q = a; printf("%d\n", q[1]); }
    return p[1];
}
static int siblings(void) {
    int x = 20; int *p = &x;
    { int x = 21; (void) x; }
    { int x = 22; int *q = &x; printf("%d\n", *q + *p); }
    return *p;
}
static int members(void) {
    struct pt s = { 30, 31 }; int *p = &s.b;
    { struct pt s = { 40, 41 }; int *q = &s.a; printf("%d\n", *q); }
    return *p;
}
int main(void) {
    printf("%d %d %d %d %d\n", twice(), broken(), arrays(), siblings(), members());
    return 0;
}

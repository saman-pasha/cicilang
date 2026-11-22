/* nullcopies.c (1.6.18): what a pointer that its null test found null is given to in its branch, each right -- a copy
   into a local, written with ! and with ==, an assignment to a local, a store into a global and into a struct's field,
   a copy into an own pointer, a copy in a branch that the paths join after, and one in the else branch of a test that
   finds it not null; 1.6.18 made such a pointer one that holds nothing the check follows, and its copy was new memory
   to the check until the copy was repaired before the commit; each prints as clang's build with `own' defined empty, as
   C and as C++ */
#include <stdio.h>
#include <stdlib.h>
struct s { char *p; };
char *g;
static char *maybe(int n) {
    if (n <= 0) return NULL;
    return malloc((size_t)n);
}
static int copy_decl(int n) {
    char *q = maybe(n);
    if (!q) { char *r = q; return r == NULL ? 10 : -1; }
    q[0] = 'a';
    int v = q[0];
    free(q);
    return v;
}
static int copy_eq(int n) {
    char *q = maybe(n);
    if (q == NULL) { char *r = q; return r ? -1 : 11; }
    free(q);
    return 1;
}
static int assign_local(int n) {
    char *q = maybe(n);
    char *r = NULL;
    if (!q) { r = q; return r ? -1 : 12; }
    free(q);
    return 2;
}
static int store_global(int n) {
    char *q = maybe(n);
    if (!q) { g = q; return g ? -1 : 13; }
    free(q);
    return 3;
}
static int store_field(int n) {
    char *q = maybe(n);
    if (!q) { struct s v; v.p = q; return v.p ? -1 : 14; }
    free(q);
    return 4;
}
static int own_copy(int n) {
    char *q = maybe(n);
    if (!q) { own char *o = q; return o ? -1 : 15; }
    free(q);
    return 5;
}
static int joined(int n) {
    char *q = maybe(n);
    int k = 6;
    if (!q) { char *r = q; k = r ? -1 : 16; }
    free(q);
    return k;
}
static int else_branch(int n) {
    char *q = maybe(n);
    if (q) { q[0] = 'b'; } else { char *r = q; return r ? -1 : 17; }
    int v = q[0] == 'b' ? 7 : -1;
    free(q);
    return v;
}
int main(void) {
    printf("%d %d %d %d", copy_decl(0), copy_eq(0), assign_local(0), store_global(0));
    printf(" %d %d %d %d\n", store_field(0), own_copy(0), joined(0), else_branch(0));
    printf("%d %d %d %d", copy_decl(4), copy_eq(4), assign_local(4), store_global(4));
    printf(" %d %d %d %d\n", store_field(4), own_copy(4), joined(4), else_branch(4));
    return 0;
}

/* reallocs.c -- realloc's old block and the null tests of an assignment (1.6.34), built as C and as C++. C17 7.22.3.5/3-4:
   where realloc gives a new block the old one is freed, and where it gives a null pointer the old one is not freed and
   its value is unchanged. The safe part follows the old block by the result's null test; a null test of an assignment
   tests its left operand (6.5.16/3), and a loop's condition is evaluated again after each pass (6.8.5/4). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the result tested; the old block given back where it is null */
static int grow_tested(size_t n) {
    char *p = (char *)malloc(4); if (!p) return -1;
    strcpy(p, "abc");
    char *q = (char *)realloc(p, n);
    if (!q) { free(p); return -1; }
    int k = (int)strlen(q); free(q); return k;
}
/* the result tested against NULL, the old name given the new block */
static int grow_renamed(size_t n) {
    char *p = (char *)malloc(4); if (!p) return -1;
    p[0] = 'x'; p[1] = 0;
    char *q = (char *)realloc(p, n);
    if (q == NULL) { free(p); return -1; }
    p = q; p[1] = 'y'; p[2] = 0;
    int k = (int)strlen(p); free(p); return k;
}
/* the result assigned in the test */
static int grow_in_test(size_t n) {
    char *p = (char *)malloc(4); if (!p) return -1;
    char *q;
    if ((q = (char *)realloc(p, n)) == NULL) { free(p); return -1; }
    memset(q, 'z', n - 1); q[n - 1] = 0;
    int k = (int)strlen(q); free(q); return k;
}
/* each arm gives back the block that it has */
static int grow_arms(size_t n) {
    char *p = (char *)malloc(4); if (!p) return -1;
    char *q = (char *)realloc(p, n);
    int k;
    if (q) { k = 1; free(q); } else { k = 0; free(p); }
    return k;
}
/* the failure ends the program; the old name takes the result */
static int grow_self(size_t n) {
    char *p = (char *)malloc(4); if (!p) return -1;
    char *q = (char *)realloc(p, n);
    if (!q) abort();
    q[0] = 0;
    free(q);
    p = (char *)malloc(2); if (!p) return -1;
    p = (char *)realloc(p, n);
    int k = p != NULL;
    free(p); return k;
}
/* the null tests of an assignment: the left operand tested */
static int tested_assignments(void) {
    char *q;
    if ((q = (char *)malloc(4)) == NULL) return -1;
    q[0] = 1; free(q);
    FILE *f;
    if (!(f = tmpfile())) return -1;
    fputs("x", f); fclose(f);
    char *r;
    int k = 0;
    if ((r = (char *)malloc(4))) { k = 1; free(r); }
    return k;
}
static char *next_block(int i) { return i < 3 ? (char *)malloc(4) : NULL; }
/* loops whose condition assigns: evaluated again before each pass */
static int loop_conditions(void) {
    char *q; int i = 0, n = 0;
    while ((q = next_block(i++)) != NULL) { n++; free(q); }
    int m = 0;
    while ((q = (char *)malloc(4)) != NULL && m < 3) { m++; free(q); }
    free(q);
    int c = 0;
    for (i = 0; (q = next_block(i)) != NULL; i++) { c++; free(q); }
    return n * 100 + m * 10 + c;
}
int main(void) {
    printf("%d %d %d %d %d\n", grow_tested(64), grow_renamed(64), grow_in_test(8), grow_arms(64), grow_self(64));
    printf("%d %d\n", tested_assignments(), loop_conditions());
    return 0;
}

/* The order of an assignment's operands: C leaves it unspecified (6.5.16/3), and clang evaluates the right operand first,
   as C++17 requires ([expr.ass]/1); a compound assignment reads its left operand after the right one (0.197) */
#include <stdio.h>
static int cells[4];
static int n = 0;
static int *slot(const char *w, int i) { printf("%s ", w); return &cells[i]; }
static int val(const char *w, int v) { printf("%s ", w); return v; }
static int bump(void) { return ++n; }
int main(void) {
    *slot("L", 1) = val("R", 7);
    *slot("L2", 2) += val("R2", 5);
    printf("| %d %d\n", cells[1], cells[2]);
    n = 0; n += bump(); int after = n;
    int k = 0; k = k + bump();
    printf("%d %d %d\n", after, n, k);
    return 0;
}

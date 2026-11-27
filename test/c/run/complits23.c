/* C23's static compound literal (1.6.31; C23 6.5.2.5/5): a static object of its block, initialized once, whose address
   outlives the call -- returned, counted over calls, an array's value and a member's; gcc's output, since clang 23 reads
   no storage class there. The literal was the block's alloca, its storage class dropped */
#include <stdio.h>
struct p { int x, y; };
static int *keep(void) { return &(static int){ 7 }; }
static int *arr(void) { return (static int[]){ 1, 2, 3 }; }
static struct p *rec(void) { return &(static struct p){ 3, 4 }; }
static int count(void) { int *c = &(static int){ 0 }; return ++*c; }
int main(void) {
    *keep() += 1;
    count();
    count();
    printf("%d %d %d %d %d\n", *keep(), arr()[2], rec()->y, count(), (static struct p){ 5, 6 }.x);
    return 0;
}

/* refused: a stack gives its top alone -- no at, no index, no begin (0.280) */
#include <stdio.h>
#include <stack.pl>
int main(void) {
    stack<int> s;
    push(s, 1);
    printf("%d\n", at(s, 0));
    return 0;
}

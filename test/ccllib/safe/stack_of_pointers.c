/* refused: a stack's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <stack.pl>
int main(void) {
    stack<const char *> names;
    push(names, "me");
    return 0;
}

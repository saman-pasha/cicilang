/* refused: a queue's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <queue.pl>
int main(void) {
    queue<const char *> names;
    push(names, "me");
    return 0;
}

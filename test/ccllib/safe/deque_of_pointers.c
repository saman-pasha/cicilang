/* refused: a deque's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <deque.pl>
int main(void) {
    deque<const char *> names;
    push_back(names, "me");
    return 0;
}

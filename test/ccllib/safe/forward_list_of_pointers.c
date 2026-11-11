/* refused: a forward_list's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <forward_list.pl>
int main(void) {
    forward_list<const char *> names;
    push_front(names, "me");
    return 0;
}

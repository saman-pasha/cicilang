/* refused: a list's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <list.pl>
int main(void) {
    list<const char *> names;
    push_back(names, "me");
    return 0;
}

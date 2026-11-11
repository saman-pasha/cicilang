/* refused: a set's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <set.pl>
int main(void) {
    set<const char *> names;
    insert(names, "me");
    return 0;
}

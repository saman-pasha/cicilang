/* refused: an unordered_set's element is a value with no pointer in it (CCLLIB.md's open decision 2) */
#include <unordered_set.pl>
int main(void) {
    unordered_set<const char *> names;
    insert(names, "me");
    return 0;
}

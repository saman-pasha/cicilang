/* refused: an unordered_map's value is a value with no pointer in it, and so is its key (CCLLIB.md's open decision
   2): a map of strings waits for the owner's rule on containers of owners */
#include <unordered_map.pl>
int main(void) {
    unordered_map<int, const char *> names;
    insert(names, 5, "me");
    return 0;
}

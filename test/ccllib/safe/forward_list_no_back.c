/* refused: a forward_list has no push_back, no back and no prev -- a node names the next one alone (0.278) */
#include <forward_list.pl>
int main(void) {
    forward_list<int> l;
    push_back(l, 1);
    return 0;
}

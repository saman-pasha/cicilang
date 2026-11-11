/* refused: &l[p] is a borrow of the list's arena, and push_front may replace the arena. The place p is a number and
   stays its element's (0.278) */
#include <stdio.h>
#include <forward_list.pl>
int main(void) {
    forward_list<int> l;
    push_front(l, 1);
    size_t p = begin(l);
    int *e = &l[p];
    push_front(l, 2);
    printf("%d %d\n", *e, at(l, p));
    return 0;
}

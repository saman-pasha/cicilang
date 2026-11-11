/* refused: &l[p] is a borrow of the list's arena, and insert may replace the arena. The place p is a number and stays
   its element's: at(l, p) after the insert is the element still (0.277) */
#include <stdio.h>
#include <list.pl>
int main(void) {
    list<int> l;
    push_back(l, 1);
    size_t p = begin(l);
    int *e = &l[p];
    insert(l, p, 2);
    printf("%d %d\n", *e, at(l, p));
    return 0;
}

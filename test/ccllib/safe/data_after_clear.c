/* <vector.pl>: data(v) through a pointer to the vector is a borrow of what the pointer borrows, and clear takes the
   vector not as const (0.274) */
#include <stdio.h>
#include <vector.pl>
static int first(vector<int> *v) {
    const int *p = data(v);
    clear(v);
    return *p;
}
int main(void) {
    v := [int; 1, 2, 3];
    printf("%d\n", first(&v));
    return 0;
}

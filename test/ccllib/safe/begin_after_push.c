/* <vector.pl>: begin(v) is a borrow of the buffer, and push_back may replace the buffer -- iterator invalidation,
   found at compile time (0.274; the safety rule of 0.265) */
#include <stdio.h>
#include <vector.pl>
int main(void) {
    v := [int; 1, 2, 3];
    const int *p = begin(v);
    push_back(v, 4);
    printf("%d\n", *p);
    return 0;
}

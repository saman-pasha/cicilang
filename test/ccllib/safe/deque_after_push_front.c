/* refused: &d[0] is a borrow of the deque's buffer, and push_front may replace the buffer. C++ keeps a reference to
   an element over a push at an end; ccllib's deque is a ring, which moves its elements when it grows (0.276) */
#include <stdio.h>
#include <deque.pl>
int main(void) {
    deque<int> d;
    push_back(d, 1);
    int *p = &d[0];
    push_front(d, 2);
    printf("%d\n", *p);
    return 0;
}

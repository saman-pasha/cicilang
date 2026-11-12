/* <span.pl>: a span of a vector is a borrow of its buffer, and push_back may replace the buffer (0.295; the safety
   rule of 0.265) */
#include <stdio.h>
#include <vector.pl>
#include <span.pl>
int main(void) {
    vector<int> v = [1, 2];
    span<int> s = v;
    push_back(v, 3);
    printf("%d\n", s[0]);
    return 0;
}

/* <span.pl>: a deque's elements do not stand in one buffer (0.295), and a span is made of no deque */
#include <deque.pl>
#include <span.pl>
int main(void) {
    deque<int> d = [1, 2, 3];
    span<int> s = d;
    return (int)size(s);
}

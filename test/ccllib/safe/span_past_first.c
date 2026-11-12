/* <span.pl>: first(s, n) of a span is named before a function of the instance takes it (0.295): its address goes */
#include <span.pl>
int main(void) {
    int a[3] = {1, 2, 3};
    span<int> s = a;
    return (int)size(first(first(s, 2), 1));
}

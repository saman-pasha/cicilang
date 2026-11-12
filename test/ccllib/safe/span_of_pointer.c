/* <span.pl>: a span is not made of a pointer alone, whose count is not known (0.295): {p, n} makes it */
#include <span.pl>
int main(void) {
    int a[3] = {1, 2, 3};
    int *p = a;
    span<int> s = p;
    return (int)size(s);
}

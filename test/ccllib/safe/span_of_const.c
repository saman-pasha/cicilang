/* <span.pl>: a span of int is not made of an array of const int (0.295): a span<const int> is */
#include <span.pl>
int main(void) {
    const int a[3] = {1, 2, 3};
    span<int> s = a;
    return (int)size(s);
}

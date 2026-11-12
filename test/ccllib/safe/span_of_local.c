/* <span.pl>: a span of a local array leaves its function (0.295) */
#include <span.pl>
static span<int> some(void) {
    int a[3] = {1, 2, 3};
    span<int> s = a;
    return s;
}
int main(void) {
    span<int> s = some();
    return (int)size(s);
}

/* <span.pl>: a span's count is its object's: a fixed extent waits (0.295) */
#include <span.pl>
int main(void) {
    int a[4] = {1, 2, 3, 4};
    span<int, 4> s = a;
    return (int)size(s);
}

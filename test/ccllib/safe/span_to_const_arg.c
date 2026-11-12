/* <span.pl>: a span of int handed where a span of const int is taken (0.295): C converts no struct at a call, and the
   span of const elements is declared first, span<const int> c = s; */
#include <span.pl>
static size_t count(span<const int> s) { return size(s); }
int main(void) {
    int a[3] = {1, 2, 3};
    span<int> s = a;
    return (int)count(s);
}

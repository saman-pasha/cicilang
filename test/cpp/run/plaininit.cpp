#include <cstdio>
struct S { int v; };
struct T { S s; int k; };
int main() {
    S s = {7};
    const S t = {8};
    S u{9};
    T w = {{3}, 4};
    printf("%d %d %d %d %d\n", s.v, t.v, u.v, w.s.v, w.k);
    return 0;
}

#include <cstdio>
#include <utility>
template <class F, class A0> int pick(F &&f, A0 &&a) { return 1 + (int) (f + a); }
template <class F, class... Args> int pick(F &&f, Args &&...as) { return 100 + (int) sizeof...(as) + (int) f; }
template <class F, class A0, class A1> int pick3(F &&, A0 &&, A1 &&) { return 3; }
template <class F, class... Args> int pick3(F &&, Args &&...) { return 300; }
int main() {
    int x = 2, y = 3;
    printf("%d %d %d %d\n", pick(x, y), pick(x), pick(x, y, x), pick3(x, y, x));
    return 0;
}

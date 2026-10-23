#include <cstdio>
consteval int cev(int x) { return x + 1; }
consteval int twice(int x) { return cev(x) * 2; }
template <class T> constexpr int prop(T x) { return cev(x) + 10; }
template <class T> constexpr T deep(T x) { return prop(x) * 3; }
struct W { int v; };
template <class T> constexpr int fieldp(T w) { return cev(w.v); }
int main() {
    constexpr int a = prop(4);
    int b = prop(5);
    int c = twice(6);
    int d = deep(1);
    int e = fieldp(W{8});
    std::printf("%d %d %d %d %d\n", a, b, c, d, e);
}

// an array new of a class with a destructor in a constant evaluation: its cookie, the elements after it, a delete[] (0.258)
#include <cstdio>
struct T { int v; constexpr T() : v(1) {} constexpr T(int k) : v(k) {} constexpr ~T() {} };
constexpr int h() { T *p = new T[3]; int s = p[0].v + p[1].v + p[2].v; delete[] p; return s; }
constexpr int h2() { T *p = new T[3]; p[1].v = 5; int s = p[0].v + p[1].v + p[2].v; delete[] p; return s; }
constexpr int k() { int a[3] = {1, 2, 3}; int *q = a; *(q + 1) = 7; return a[1]; }
static_assert(h() == 3 && h2() == 7 && k() == 7);
int main() { std::printf("%d %d %d\n", h(), h2(), k()); }

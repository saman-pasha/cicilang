// A pseudo-destructor call evaluates its object expression: `(--p)->~T()' over an int decrements (valarray's __clear).
#include <cstdio>
template <class T> int clear(T *b, T *e) { int n = 0; while (e != b) { (--e)->~T(); ++n; } return n; }
struct S { int v; };
int main() { int a[4] = {1, 2, 3, 4}; S s[3] = {{1}, {2}, {3}}; std::printf("%d %d\n", clear(a, a + 4), clear(s, s + 3)); return 0; }

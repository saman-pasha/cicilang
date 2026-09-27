#include <cstdio>
template <class T> int kind(T &x) { x = x + 1; return 1; }
template <class T> int kind(const T &x) { (void) x; return 2; }
template <class T> int which(const T &) { return 20; }
template <class T> int which(T &) { return 10; }
struct S { int v; };
template <class T> int cls(T &s) { s.v++; return 100; }
template <class T> int cls(const T &s) { return 200 + s.v; }
int main() {
    int a = 1;
    const int b = 5;
    int r1 = kind(a);
    int r2 = kind(b);
    S s = {7};
    const S t = {8};
    printf("%d %d %d\n", r1, r2, a);
    printf("%d %d %d %d\n", which(a), which(b), cls(s), cls(t));
    printf("%d\n", s.v);
    return 0;
}

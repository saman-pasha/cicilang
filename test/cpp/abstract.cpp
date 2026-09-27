#include <cstdio>
struct Shape { virtual int area() const = 0; virtual ~Shape() {} };
struct Sq : Shape { int s; Sq(int s0) : s(s0) {} int area() const override { return s * s; } };
int main() {
    Shape x;
    printf("%d\n", x.area());
    return 0;
}

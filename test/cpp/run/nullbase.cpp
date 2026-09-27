#include <cstdio>
struct A { int a; };
struct B { int b; int g() { return b * 2; } };
struct C : A, B { int c; };
int main() {
    C *p = nullptr;
    B *q = p;
    C obj;
    obj.b = 21;
    B *r = &obj;
    C *back = nullptr;
    printf("%d %d %d %d\n", q == nullptr, r == nullptr, r->g(), back == nullptr);
    return 0;
}

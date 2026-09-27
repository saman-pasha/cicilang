// a pointer to member function is the ABI's { ptr, adj }: 16 bytes; a non-virtual member called through it,
// a VIRTUAL member dispatched through the object's own table, a pointer passed by value and returned
#include <cstdio>
struct Shape {
    int k;
    Shape(int k) : k(k) {}
    virtual ~Shape() {}
    virtual int area() const { return k; }
    int twice() const { return 2 * k; }
};
struct Square : Shape {
    Square(int k) : Shape(k) {}
    int area() const override { return k * k; }
};
typedef int (Shape::*Fn)() const;
int apply(const Shape &s, Fn f) { return (s.*f)(); }
Fn pick(int which) { return which ? &Shape::area : &Shape::twice; }
int main() {
    Square sq(5);
    Shape sh(3);
    Shape *p = &sq;
    Fn a = &Shape::area, t = &Shape::twice;
    printf("%d %d %d %d\n", (int) sizeof(Fn), (sq.*a)(), (p->*a)(), (sh.*a)());
    printf("%d %d %d %d\n", (p->*t)(), apply(sq, a), apply(sh, pick(1)), apply(sq, pick(0)));
    return 0;
}

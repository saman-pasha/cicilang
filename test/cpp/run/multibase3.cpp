#include <cstdio>
#include <typeinfo>
struct Shape { virtual ~Shape() {} virtual int area() const { return 0; } };
struct Named { virtual ~Named() {} virtual const char *name() const { return "named"; } };
struct Square : Shape, Named {
    int side;
    Square(int s) : side(s) {}
    int area() const override { return side * side; }
    const char *name() const override { return "square"; }
};
struct Circle : Shape { int r = 2; int area() const override { return 3 * r * r; } };
int main() {
    Square sq(5); Circle ci;
    Named *n = &sq; Shape *s1 = &sq; Shape *s2 = &ci;
    std::printf("%s %s %s\n", typeid(*n).name(), typeid(*s1).name(), typeid(*s2).name());
    Square *back = dynamic_cast<Square *>(n);
    std::printf("%d %d\n", back == &sq, back->area());
    Named *cross = dynamic_cast<Named *>(s1);
    std::printf("%d %s\n", cross == n, cross ? cross->name() : "null");
    std::printf("%d %d\n", dynamic_cast<Named *>(s2) == nullptr, dynamic_cast<Square *>(s2) == nullptr);
    std::printf("%d\n", typeid(*n) == typeid(Square));
    return 0;
}

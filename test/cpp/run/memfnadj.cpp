#include <cstdio>
struct Shape { int s = 10; virtual ~Shape() {} virtual int area() const { return s; } };
struct Named { int k = 7; virtual ~Named() {} virtual int rank() const { return k; } int twice() const { return 2 * k; } };
struct Square : Shape, Named { int side = 4; int area() const override { return side * side; } int rank() const override { return 100 + k; } };
int main() {
    Square sq;
    int (Named::*pn)() const = &Named::twice;
    int (Square::*ps)() const = pn;
    int (Named::*pv)() const = &Named::rank;
    int (Square::*psv)() const = pv;
    int (Square::*pa)() const = &Square::area;
    Named &nr = sq;
    std::printf("%d %d %d %d %d\n", (sq.*ps)(), (sq.*psv)(), (sq.*pa)(), (nr.*pn)(), (nr.*pv)());
    std::printf("%zu\n", sizeof ps);
    return 0;
}

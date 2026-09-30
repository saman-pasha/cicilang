#include <cstdio>
struct Shape { int sid = 1; virtual ~Shape() { std::printf("~Shape\n"); } virtual int area() const { return 0; } };
struct Named { const char *nm = "named"; virtual ~Named() { std::printf("~Named\n"); } virtual const char *name() const { return nm; } virtual int rank() const { return 5; } };
struct Square : Shape, Named {
    int side;
    Square(int s) : side(s) {}
    ~Square() { std::printf("~Square\n"); }
    int area() const override { return side * side; }
    const char *name() const override { return "square"; }
};
static void show(const Named &n) { std::printf("%s %d\n", n.name(), n.rank()); }
int main() {
    Square sq(3);
    Shape *s = &sq; Named *n = &sq;
    std::printf("%d %s %d\n", s->area(), n->name(), n->rank());
    show(sq);
    std::printf("%d\n", (void *) n != (void *) s);
    Named *h = new Square(4);
    std::printf("%s\n", h->name());
    delete h;
    return 0;
}

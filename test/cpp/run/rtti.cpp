#include <cstdio>
#include <typeinfo>
struct Shape { virtual ~Shape() {} virtual int sides() const { return 0; } };
struct Tri : Shape { int sides() const override { return 3; } };
struct Sq : Shape { int sides() const override { return 4; } int side = 2; };
struct Cube : Sq { int depth = 5; };
struct Plain { int x; };
static const char *kind(const Shape &s) {
    if (dynamic_cast<const Tri *>(&s)) return "tri";
    if (const Sq *q = dynamic_cast<const Sq *>(&s)) return q->side == 2 ? "square" : "?";
    return "shape";
}
int main() {
    Tri t; Sq q; Cube c; Shape s;
    Shape *ps[4] = { &t, &q, &c, &s };
    for (int i = 0; i < 4; i++) std::printf("%s %s %d\n", typeid(*ps[i]).name(), kind(*ps[i]), ps[i]->sides());
    std::printf("%s %s %s %s\n", typeid(int).name(), typeid(Plain).name(), typeid(3.5).name(), typeid(Tri).name());
    std::printf("%d %d %d\n", typeid(*ps[0]) == typeid(Tri), typeid(*ps[1]) == typeid(Tri), typeid(*ps[2]) != typeid(Sq));
    Cube *cp = dynamic_cast<Cube *>(ps[2]);
    Cube *cn = dynamic_cast<Cube *>(ps[1]);
    std::printf("%d %d %d\n", cp ? cp->depth : -1, cn == nullptr, dynamic_cast<Sq *>(ps[2]) != nullptr);
    Sq &qr = dynamic_cast<Sq &>(*ps[2]);
    std::printf("%d\n", qr.side);
    Shape *np = nullptr;
    std::printf("%d\n", dynamic_cast<Tri *>(np) == nullptr);
    return 0;
}

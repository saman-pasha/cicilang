#include <cstdio>
#include <functional>
struct Pt { int x; int y; int len() const { return x + y; } int plus(int k) const { return x + k; } };
int main() {
    Pt p{3, 4};
    printf("%d %d\n", std::invoke(&Pt::x, p), std::invoke(&Pt::len, p));
    int Pt::*pm = &Pt::y;
    printf("%d\n", p.*pm);
    auto f = std::bind(&Pt::plus, std::ref(p), 10);
    p.x = 5;
    printf("%d %d\n", f(), std::mem_fn(&Pt::y)(p));
    return 0;
}

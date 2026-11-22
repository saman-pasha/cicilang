// What the void-value rules of 1.6.14 keep in C++: a name whose overloads differ in their result, one of them void, called
// for a value through the overload that gives one -- as an argument, a member's initializer, a new value, a constructor's
// argument, a template's argument, a cast's operand and an initializer --, a void value where no value is taken, and the
// conditionals that a throw arm, a rethrow arm or two void arms make
#include <cstdio>
int z;
void ov2(double) { z += 100; }
int ov2(int v) { return v + 1; }
void f() { z++; }
int g(int v) { return v * 2; }
template<class T> T id(T v) { return v; }
struct M { int v; M(int x) : v(x) {} };
struct T { int m; int n = ov2(4); T() : m(ov2(1)) {} };
int main() {
    std::printf("%d\n", g(ov2(1)));
    T t; std::printf("%d %d\n", t.m, t.n);
    int *p = new int(ov2(2)); std::printf("%d\n", *p); delete p;
    M m(ov2(3)); std::printf("%d\n", m.v);
    std::printf("%d\n", id(ov2(5)));
    std::printf("%d\n", static_cast<int>(ov2(6)) + (int)ov2(7));
    int x = ov2(8), y{ov2(9)}; std::printf("%d %d\n", x, y);
    ov2(1.5); std::printf("%d\n", z);
    (void)f(); f(), f(); z ? f() : f(); static_cast<void>(f()); void(f());
    std::printf("%d\n", z);
    int w = z ? 1 : throw 2; std::printf("%d\n", w);
    auto q = [](int v) { return v ? v : throw 3; }; std::printf("%d\n", q(4));
    int r = z ? 1 : throw; std::printf("%d\n", r);
    return 0;
}

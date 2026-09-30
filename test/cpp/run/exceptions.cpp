#include <cstdio>
struct Err { int code; };
struct Base { virtual ~Base() {} virtual int id() const { return 1; } };
struct Derived : Base { int id() const override { return 2; } };
struct Noisy { int n; Noisy(int k) : n(k) {} ~Noisy() { std::printf("~Noisy %d\n", n); } };
static int depth(int k) { Noisy guard(k); if (k == 0) throw Err{42}; return depth(k - 1) + 1; }
static void thrower(int w) {
    if (w == 1) throw 7;
    if (w == 2) throw 2.5;
    if (w == 3) throw Derived();
    if (w == 4) throw Err{9};
    std::printf("no throw\n");
}
int main() {
    for (int w = 0; w <= 4; w++) {
        try { thrower(w); std::printf("after %d\n", w); }
        catch (int i) { std::printf("int %d\n", i); }
        catch (double d) { std::printf("double %.1f\n", d); }
        catch (const Base &b) { std::printf("base %d\n", b.id()); }
        catch (...) { std::printf("other\n"); }
    }
    try { depth(2); } catch (Err &e) { std::printf("err %d\n", e.code); }
    try {
        try { throw 5; }
        catch (int i) { std::printf("inner %d\n", i); throw; }
    } catch (int j) { std::printf("outer %d\n", j); }
    int total = 0;
    for (int i = 0; i < 3; i++) { try { if (i == 1) throw i; total += 10; } catch (int x) { total += x; } }
    std::printf("total %d\n", total);
    return 0;
}

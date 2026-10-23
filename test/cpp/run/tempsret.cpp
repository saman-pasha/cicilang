// A class value returned through the hidden pointer and called at once, `make(3)(4)': the statement's temporary is
// constructed in place by the call (0.192). Copied bitwise from the call's own slot, a class that holds its own
// address pointed into that slot: a std::function's small buffer, and its destructor freed the stack.
#include <cstdint>
#include <cstdio>
#include <functional>

struct Self {
    int v;
    std::uintptr_t me;   // its own address, as an integer: the safe part follows no stored `this'
    Self(int x) : v(x), me((std::uintptr_t) this) { std::printf("Self %d\n", v); }
    Self(const Self &o) : v(o.v), me((std::uintptr_t) this) { std::printf("copy %d\n", v); }
    ~Self() { std::printf("~Self %d %s\n", v, me == (std::uintptr_t) this ? "here" : "elsewhere"); }
    int operator()(int k) const { return me == (std::uintptr_t) this ? v * k : -1; }
};

Self make(int x) { return Self(x); }

std::function<int(int)> twice() { return [](int x) { return x * 2; }; }
std::function<int(int)> add(int n) { return [n](int x) { return x + n; }; }

int main() {
    std::printf("%d\n", make(3)(4));
    std::printf("%d %d\n", twice()(5), add(10)(5));
    int s = 0;
    for (int i = 0; i < 3; i++) s += add(i)(i);
    std::printf("%d\n", s);
    std::function<int(int)> f = add(7);
    std::printf("%d\n", f(1));
    return 0;
}

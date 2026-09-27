// a closure that leaves its scope: by-value captures may go, `this' is the object's borrow, a reference capture stays
#include <cstdio>
auto make(int n) { int x = n; return [x](int k) { return x + k; }; }
auto make2(int n) { int x = n; auto f = [x, n](int k) { return x * n + k; }; return f; }
struct C {
    int n;
    C(int n) : n(n) {}
    auto adder() { return [this](int k) { return n + k; }; }
};
int apply(int k) { int y = 2; auto h = [&y](int m) { return y * m; }; y = 5; return h(k); }
int main() {
    auto f = make(3);
    auto g = make2(3);
    C c(4);
    auto a = c.adder();
    printf("%d %d %d %d\n", f(1), g(1), a(1), apply(3));
    return 0;
}

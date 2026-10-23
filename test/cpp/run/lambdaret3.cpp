// a lambda that returns a lambda: its parameter, its capture by value and by reference, a default capture, three levels, a
// generic inner lambda, `this' through, and the closure factory called where it is made
#include <cstdio>
#include <string>
struct K {
    int base = 100;
    auto maker() { return [this](int a) { return [this, a](int b) { return base + a * 10 + b; }; }; }
};
int main() {
    int x = 4;
    auto f = [x](int p) { return [x, p](int q) { return x * 100 + p * 10 + q; }; };
    auto g = [&x](int p) { return [&x, p](int q) { x += q; return x + p; }; };
    auto h = [=](int p) { return [=](int q) { return [=](int r) { return x + p + q + r; }; }; };
    auto gen = [](int k) { return [k](auto v) { return v * k; }; };
    std::string s = "ab";
    auto str = [s](int n) { return [s, n]() { std::string t; for (int i = 0; i < n; i++) t += s; return t; }; };
    K k;
    std::printf("%d %d %d\n", f(1)(2), f(3)(5), [](int p) { return [p](int q) { return p - q; }; }(9)(4));
    auto g1 = g(7); std::printf("%d %d %d\n", g1(1), g1(2), x);
    std::printf("%d %d %.1f\n", h(1)(2)(3), gen(3)(5), gen(2)(1.25));
    std::printf("%s %d\n", str(3)().c_str(), k.maker()(2)(3));
}

// a lambda returned from a lambda is one class wherever it is made (the result's deduction and the emission are two contexts), and a call's function expression is sequenced before its arguments ([expr.call]/8)
#include <cstdio>
static int n = 0;
int next() { return ++n; }
int main() {
    auto f = [](int p) { return [p](int q) { return p * 10 + q; }; };
    auto g = f(5);
    std::printf("%d\n", g(3));
    std::printf("%d\n", f(next())(next()));
}

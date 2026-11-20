// C++'s unary + over a closure ([over.built]/8, [expr.prim.lambda.closure]/8): the built-in `T *operator+(T *)' over
// the closure's conversion to a pointer to its function, the idiom that makes a lambda a plain function pointer; through
// 1.6.0 `auto k = +[](int y) { ... };' was refused, `auto(k)'
#include <cstdio>
static int apply(int (*fn)(int), int v) { return fn(v); }
int main() {
    auto k = +[](int y) { return y * 2; };
    int (*g)(int) = +[](int y) { return y + 1; };
    std::printf("%d %d %d\n", k(4), g(4), apply(+[](int y) { return y - 1; }, 4));
    return 0;
}

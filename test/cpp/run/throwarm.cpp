// A conditional whose arm is a throw-expression has the other arm's type, value and value category ([expr.cond]/2.1;
// 1.6.14): through 1.6.13 such a conditional was void and its `none' reached LLVM's parser, a lambda that returned one
// deduced void, and decltype of one over an lvalue was the prvalue's type.
// Beside it, the forms the void-value rules keep: a cast to void of a void call, a functional cast to void, a comma
#include <cstdio>
int pick(int c) { return c ? throw 1 : 2; }
int pick2(int c) { int x = c ? 3 : throw 2; return x; }
const char *name(int c) { return c == 0 ? "zero" : c == 1 ? "one" : throw c; }
void f() {}
auto fa(int c) { return c ? throw 1 : 2.5; }
auto fb(int c) { return c ? 3.5 : throw 2; }
int main() {
    std::printf("%d %d\n", pick(0), pick2(1));
    try { pick(1); } catch (int e) { std::printf("caught %d\n", e); }
    try { pick2(0); } catch (int e) { std::printf("caught %d\n", e); }
    std::printf("%s %s\n", name(0), name(1));
    try { name(7); } catch (int e) { std::printf("caught %d\n", e); }
    int z = 1; z ? f() : throw 5; std::printf("void arm\n");
    try { z = 0; z ? f() : throw 6; } catch (int e) { std::printf("caught %d\n", e); }
    auto g = [](int v) { return v ? throw 8 : v + 1; };
    std::printf("lambda %d\n", g(0));
    try { g(1); } catch (int e) { std::printf("caught %d\n", e); }
    int arr[2] = {7, 8}; std::printf("%d\n", 1[arr]);
    static_cast<void>(f()); void(f()); (void)(f(), 1);
    int one = 1; auto x = one ? 2.5 : throw 1;
    std::printf("%g %zu %zu\n", x, sizeof(one ? 2.5 : throw 1), sizeof(one ? throw 1 : 2.5));
    decltype(one ? one : throw 1) w = one; w = 7; decltype(one ? throw 1 : one) w2 = one; w2 += 1; std::printf("%d\n", one);
    std::printf("%g %g\n", fa(0), fb(1));
    return 0;
}

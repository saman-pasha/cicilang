// A local constant is its body's (0.195): a function's `const int K = 3;' shadows the file-scope K in its own body and
// no further; a `const' PARAMETER, which holds no constant, shadows a constant and an enumerator of its name; a local
// constant is a constant in a lambda that does not capture it, an array's bound with an initializer, a template argument,
// std::array's size and a case label, a generic lambda's too; an inner block's constant has left when the block ends
#include <array>
#include <cstdio>
const int K = 8;
int n = 5;
enum { E = 6 };
template <int N> struct V { static constexpr int value = N; };
void f() { const int K = 3; int a[K]; std::printf("%zu\n", sizeof a); }
void f2() { const int n = 3; std::printf("%d\n", n); }
int b[K];
void g(const int K) { int a[K]; std::printf("%zu\n", sizeof a); }
void h(const int E) { int a[E]; std::printf("%zu\n", sizeof a); }
int g2() { int a[n]; return (int) sizeof a; }
int f3() { { const int K = 3; (void) K; } int a[K]; return (int) sizeof a; }
int main() {
    f(); f2(); g(2); h(3);
    std::printf("%zu %d %d\n", sizeof b, g2(), n);
    const int m = 3;
    int a[m] = {1, 2, 3};
    constexpr int m2 = m * 2;
    std::array<int, m2> c{};
    V<m + m2> v;
    switch (a[2]) { case m: std::printf("three\n"); break; default: break; }
    auto l = [] { int d[m]; return (int) sizeof d; };
    std::printf("%zu %zu %d %d %d\n", sizeof a, c.size(), v.value, a[0] + a[2], l());
    auto gl = [](auto x) { int d[m]; return (int) sizeof d + x; };
    std::printf("%d %d\n", f3(), gl(1));
    return 0;
}

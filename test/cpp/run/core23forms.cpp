#include <cstdio>
#include <cstddef>
constexpr int fact(int n) { int r = 1; for (int i = 2; i <= n; ++i) r *= i; return r; }
constexpr int withstatic(int n) { static constexpr int base = 100; return base + n; }
constexpr int g23(int n) { if (n > 100) { goto big; } return n; big: return -1; }
struct Fn { static int operator()(int a, int b) { return a - b; } };
template <class... Ts> constexpr int nargs(Ts...) { return sizeof...(Ts); }
int main() {
    constexpr int f5 = fact(5);
    constexpr int ws = withstatic(7);
    constexpr int g = g23(4);
    auto lam = [](this auto self, int k) -> int { return k <= 1 ? 1 : k * self(k - 1); };
    std::printf("%d %d %d %d %d %d\n", f5, ws, g, Fn{}(9, 4), lam(5), nargs(1, 2, 3));
    std::size_t z = 10uz; auto d = auto(z);
    std::printf("%zu\n", d);
}

#include <cstdio>
constexpr int f(int x) { if consteval { return x * 10; } else { return x; } }
constexpr int h(int x) { if !consteval { return -x; } else { return x + 100; } }
constexpr int g = f(4);
static_assert(f(2) == 20);
int arr[h(1)];
int main() { int n = 5; std::printf("%d %d %d %d %zu\n", g, f(n), h(n), h(3) + 0, sizeof arr / sizeof arr[0]); return 0; }

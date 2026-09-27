#include <cstdio>
consteval int sq(int x) { return x * x; }
consteval int fib(int n) { int a = 0, b = 1; for (int i = 0; i < n; i++) { int t = a + b; a = b; b = t; } return a; }
template <int N> struct Box { static const int v = N; };
int main() {
    constexpr int k = sq(7);
    int arr[sq(3)] = {};
    printf("%d %d %d %d %d\n", k, sq(4), fib(10), Box<fib(7)>::v, (int) (sizeof(arr) / sizeof(int)));
    return 0;
}

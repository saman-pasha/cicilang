#include <functional>
#include <cstdio>
int add3(int a, int b, int c) { return a + b * 10 + c * 100; }
bool is_odd(int x) { return x % 2 != 0; }
int main() {
    auto f = std::bind_front(add3, 1, 2);
    auto g = std::not_fn(is_odd);
    printf("%d %d %d\n", f(3), (int) g(3), (int) g(4));
    return 0;
}

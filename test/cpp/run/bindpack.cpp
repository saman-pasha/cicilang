#include <cstdio>
#include <tuple>
#include <utility>
struct P3 { int a, b, c; };
template <class T> auto sum_all(T t) { auto [...xs] = t; return (xs + ...); }
template <class T> int count(T t) { auto [first, ...rest] = t; return first * 10 + (int) sizeof...(rest); }
template <class T> int last(T t) { auto [...init, z] = t; return z; }
template <class T> int middle(T t) { auto &[a, ...m, z] = t; return (m + ... + 0) + a * 0 + z * 0; }
int mul(int x, int y, int w) { return x * y * w; }
template <class T> int apply3(T t) { auto [...xs] = t; return mul(xs...); }
int main() {
    std::printf("%d %d %d %d\n", sum_all(std::tuple{1, 2, 3}), count(std::tuple{4, 5, 6, 7}), last(P3{1, 2, 9}), middle(std::tuple{1, 20, 30, 4}));
    std::printf("%d %d\n", apply3(std::tuple{2, 3, 4}), sum_all(P3{5, 6, 7}));
    auto [x [[maybe_unused]], y] = std::pair{1, 2};
    auto [_, _, w] = std::tuple{3, 4, 5};
    std::printf("%d %d\n", y, w);
}

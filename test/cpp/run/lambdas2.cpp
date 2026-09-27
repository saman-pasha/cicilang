#include <cstdio>
#include <concepts>
struct Acc {
    int n;
    auto by_copy() { return [*this]() { return n * 2; }; }
    auto by_ref() { return [this]() { return n * 3; }; }
};
template <class... Ts> int sum_all(Ts... xs) {
    auto f = [xs...]() { return (xs + ... + 0); };
    return f();
}
template <std::integral T> T twice(T x) { return x * 2; }
int half(std::integral auto x) { return x / 2; }
int main() {
    Acc a{5};
    auto c = a.by_copy();
    auto r = a.by_ref();
    a.n = 7;
    printf("%d %d\n", c(), r());
    printf("%d %d %d\n", sum_all(1, 2, 3), twice(21), half(9));
    return 0;
}

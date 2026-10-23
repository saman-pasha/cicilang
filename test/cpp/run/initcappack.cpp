#include <cstdio>
#include <string>
#include <utility>
int sum3(int a, int b, int c) { return a * 100 + b * 10 + c; }
template <class... Ts> int moved(Ts... ts) { auto f = [...xs = std::move(ts)] { return (xs + ... + 0); }; return f(); }
template <class... Ts> int counted(Ts... ts) { return [...xs = ts]() { return (int) sizeof...(xs); }(); }
template <class... Ts> void bump(Ts &... ts) { [&...rs = ts] { ((rs += 1), ...); }(); }
template <class... Ts> int spread(Ts... ts) { auto g = [...vs = ts * 2] { return sum3(vs...); }; return g(); }
template <class... Ts> std::string joined(Ts... ts) { return [...ss = std::string(ts)] { return (ss + ... + std::string("!")); }(); }
int main() {
    int a = 1, b = 2;
    bump(a, b);
    std::printf("%d %d %d %d %d\n", moved(1, 2, 3), counted(1, 'c', 2.0), a, b, spread(1, 2, 3));
    std::printf("%s\n", joined("x", "y").c_str());
}

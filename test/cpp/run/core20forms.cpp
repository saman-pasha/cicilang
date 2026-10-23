#include <cstdio>
#include <type_traits>
template <auto N> struct X { static constexpr auto v = N; };
template <auto... Ns> constexpr int count = sizeof...(Ns);
constinit int ci = 42;
struct C { int k = 3; int f() { auto l = [=, this] { return k + 1; }; return l(); } };
constexpr int sq(int x) { if (x < 0) { static_assert(true); } return x * x; }
template <class T> T::value_type firstv(const T &t) { return t.v; }
struct H { using value_type = int; int v = 9; };
int main() {
    auto nd = [] [[nodiscard]] () { return 5; };
    auto ce = [](int x) consteval { return x * 3; };
    constexpr int c3 = ce(2);
    std::printf("%d %d %d %d %d\n", (int) X<5>::v, (int) (X<'a'>::v == 'a'), count<1, 'b', 3u>, ci, C{}.f());
    std::printf("%d %d %d %d\n", nd(), c3, sq(4), firstv(H{}));
}

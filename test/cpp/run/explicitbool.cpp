// C++20's explicit(bool) ([dcl.fct.spec]/4): a constructor or a conversion function explicit where its condition holds
#include <cstdio>
#include <type_traits>
#include <optional>
#include <utility>
#include <string>
template <class T> struct W {
    T v;
    template <class U> explicit(!std::is_convertible_v<U, T>) W(U u) : v(u) {}
};
struct A { explicit A(int) {} };
struct B { B(int) {} };
struct E { explicit(true) operator int() const { return 3; } explicit(false) operator long() const { return 4; } };
int main() {
    W<long> w = 5;
    std::printf("%ld %d %d\n", w.v, (int) std::is_convertible_v<int, W<long>>, (int) std::is_convertible_v<int *, W<long>>);
    std::printf("%d %d\n", (int) std::is_convertible_v<int, std::optional<A>>, (int) std::is_convertible_v<int, std::optional<B>>);
    std::printf("%d %d\n", (int) std::is_convertible_v<std::pair<int, int>, std::pair<A, int>>, (int) std::is_convertible_v<std::pair<int, int>, std::pair<B, int>>);
    E e; long l = e; int i = static_cast<int>(e);
    std::printf("%ld %d %d %d\n", l, i, (int) std::is_convertible_v<E, int>, (int) std::is_convertible_v<E, long>);
    std::pair<std::string, int> ps = {"a", 1};
    std::printf("%s %d\n", ps.first.c_str(), ps.second);
}

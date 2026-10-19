// C++20 (P0704): an rvalue object takes a member function whose ref-qualifier is `&' when it is `const' (0.181)
#include <cstdio>
#include <functional>
#include <type_traits>

struct A {
    int v = 5;
    int clf(int k) const & { return v + k; }
    int lf(int k) & { return v - k; }
    int cvlf(int k) const volatile & { return k; }
};

int main() {
    int (A::*q)(int) const & = &A::clf;
    std::printf("%d %d %d\n", (A{}.*q)(2), std::invoke(&A::clf, A{}, 4), std::invoke(q, A{}, 6));
    std::printf("%d %d %d %d\n", (int) std::is_invocable_v<int (A::*)(int) const &, A, int>, (int) std::is_invocable_v<int (A::*)(int) &, A, int>,
                (int) std::is_invocable_v<int (A::*)(int) const volatile &, A, int>, (int) std::is_invocable_v<int (A::*)(int) const &, const A &, int>);
    return 0;
}

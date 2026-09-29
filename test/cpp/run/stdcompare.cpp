#include <cstdio>
#include <compare>
// C++20: <compare>'s ordering classes, libc++'s own -- a scalar <=> answers std::strong_ordering (std::partial_ordering
// for floating operands), a defaulted <=> the common category of its members, and the comparisons with the literal 0
// go to the hidden friends the header writes over _CmpUnspecifiedParam (0.101)
struct P { int x; int y; auto operator<=>(const P &) const = default; };
struct Q { double d; int k; auto operator<=>(const Q &) const = default; };
struct R { P p; int z; std::strong_ordering operator<=>(const R &) const = default; };
struct W { double a; std::partial_ordering operator<=>(const W &) const = default; };
int main() {
    int a = 3, b = 5;
    std::strong_ordering o = a <=> b;
    printf("%d %d %d %d\n", (int) (o < 0), (int) (o == 0), (int) ((b <=> a) > 0), (int) (o == std::strong_ordering::less));
    printf("%d %d %d\n", (int) std::is_lt(o), (int) std::is_gteq(o), (int) std::is_neq(a <=> a));
    P p{1, 2}, q{1, 3};
    printf("%d %d %d %d\n", (int) (p < q), (int) (p == q), (int) ((q <=> p) == std::strong_ordering::greater), (int) (p <= p));
    double d = 1.5, nan = 0.0 / 0.0;
    std::partial_ordering po = d <=> 2.0, un = nan <=> 1.0;
    printf("%d %d %d %d %d\n", (int) (po < 0), (int) std::is_lt(po), (int) (un == std::partial_ordering::unordered), (int) (un < 0), (int) (un >= 0));
    Q u{1.0, 2}, v{1.0, 3};
    printf("%d %d %d\n", (int) (u < v), (int) ((v <=> u) == std::partial_ordering::greater), (int) ((u <=> u) == 0));
    R r{{1, 2}, 9}, t{{1, 3}, 0};
    printf("%d %d %d\n", (int) (r < t), (int) ((t <=> r) > 0), (int) (r == r));
    Q n1{nan, 1}, n2{1.0, 1};                                                                   // a NaN member: the defaulted <=> is unordered (0.103)
    printf("%d %d %d %d\n", (int) ((n1 <=> n2) == std::partial_ordering::unordered), (int) (n1 < n2), (int) (n1 >= n2), (int) ((n2 <=> n2) == 0));
    W w1{nan}, w2{0.0};
    printf("%d %d %d\n", (int) ((w1 <=> w2) == std::partial_ordering::unordered), (int) ((w2 <=> w2) == 0), (int) ((w2 <=> w1) < 0));
    int arr[2] = {0, 0}; int *s1 = arr, *s2 = arr + 1;
    std::strong_ordering ps = s1 <=> s2;
    printf("%d %d\n", (int) (ps < 0), (int) (std::weak_ordering::equivalent == 0));
    return 0;
}

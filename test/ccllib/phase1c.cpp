// the twin of phase1c.c over std:: (phase 1c): clang++ builds it over libc++ and it prints phase1c.expect
#include <algorithm>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstdio>
#include <limits>
#include <numeric>
#include <random>
#include <ratio>
#include <vector>

int main() {
    std::vector<int> v = {5, 3, 9, 1, 3};
    std::sort(v.begin(), v.end());
    std::printf("sort:");
    for (int x : v) std::printf(" %d", x);
    std::printf("\n");
    std::reverse(v.begin(), v.end());
    std::printf("reverse:");
    for (int x : v) std::printf(" %d", x);
    std::printf("\n");
    std::printf("count=%zu find=%zu min=%zu max=%zu lower=%zu upper=%zu binary=%d\n",
                (size_t)std::count(v.begin(), v.end(), 3),
                (size_t)(std::find(v.begin(), v.end(), 9) - v.begin()),
                (size_t)(std::min_element(v.begin(), v.end()) - v.begin()),
                (size_t)(std::max_element(v.begin(), v.end()) - v.begin()),
                (size_t)(std::lower_bound(v.begin(), v.end(), 3) - v.begin()),
                (size_t)(std::upper_bound(v.begin(), v.end(), 3) - v.begin()),
                (int)std::binary_search(v.begin(), v.end(), 9));
    std::sort(v.begin(), v.end(), [](int a, int b) { return a < b; });
    std::printf("sort_by:");
    for (int x : v) std::printf(" %d", x);
    std::printf("\n");
    std::printf("tests %d %d %d\n",
                (int)std::all_of(v.begin(), v.end(), [](int x) { return x > 0; }),
                (int)std::any_of(v.begin(), v.end(), [](int x) { return x > 8; }),
                (int)std::none_of(v.begin(), v.end(), [](int x) { return x > 10; }));
    std::printf("clamp %d %d\n", std::clamp(12, 0, 9), std::min(4, 7));
    std::printf("for_each:");
    std::for_each(v.begin(), v.end(), [](int x) { std::printf(" %d", x * 2); });
    std::printf("\n");
    std::printf("filter:");
    for (int x : v) if (x % 3 == 0) std::printf(" %d", x);
    std::printf("\n");
    std::printf("take:");
    for (size_t i = 0; i < 2 && i < v.size(); i++) std::printf(" %d", v[i]);
    std::printf("\n");
    std::printf("drop:");
    for (size_t i = 3; i < v.size(); i++) std::printf(" %d", v[i]);
    std::printf("\n");
    std::vector<int> w = {1, 2, 3};
    std::vector<int> u = {1, 2, 3};
    std::vector<int> t = {1, 2, 4};
    std::vector<int> w5 = {1, 2, 3, 4, 5};
    std::printf("equal %d %d lex %d %d\n", (int)std::equal(w.begin(), w.end(), u.begin()),
                (int)std::equal(w.begin(), w.end(), t.begin()),
                (int)std::lexicographical_compare(w.begin(), w.end(), t.begin(), t.end()),
                (int)std::lexicographical_compare(t.begin(), t.end(), w.begin(), w.end()));
    std::vector<int> pv = {5, 3, 9, 1, 3};
    std::partial_sort(pv.begin(), pv.begin() + 2, pv.end());
    std::printf("partial_sort:");
    for (size_t i = 0; i < 2; i++) std::printf(" %d", pv[i]);
    std::printf("\n");

    std::printf("accumulate %d %d inner %d\n",
                std::accumulate(v.begin(), v.end(), 0),
                std::accumulate(v.begin(), v.end(), 0, [](int acc, int x) { return acc + x * x; }),
                std::inner_product(v.begin(), v.end(), w5.begin(), 0));
    std::vector<int> ps(5, 0);
    std::partial_sum(v.begin(), v.end(), ps.begin());
    std::printf("partial_sum:");
    for (int x : ps) std::printf(" %d", x);
    std::printf("\n");
    std::adjacent_difference(v.begin(), v.end(), ps.begin());
    std::printf("adjacent:");
    for (int x : ps) std::printf(" %d", x);
    std::printf("\n");
    std::iota(ps.begin(), ps.end(), 10);
    std::printf("iota:");
    for (int x : ps) std::printf(" %d", x);
    std::printf("\n");
    std::printf("gcd=%d lcm=%d midpoint=%d\n", std::gcd(18, 24), std::lcm(6, 8), std::midpoint(3, 10));

    std::printf("limits int %d %d %d %d\n", std::numeric_limits<int>::max(), std::numeric_limits<int>::min(),
                std::numeric_limits<int>::digits, std::numeric_limits<int>::digits10);
    std::printf("limits uint %u %u %d %d\n", std::numeric_limits<unsigned>::max(), std::numeric_limits<unsigned>::min(),
                (int)std::numeric_limits<unsigned>::is_signed, (int)std::numeric_limits<unsigned>::is_integer);
    std::printf("limits double %g %g %g %d %d\n", std::numeric_limits<double>::max(), std::numeric_limits<double>::min(),
                std::numeric_limits<double>::epsilon(), std::numeric_limits<double>::digits,
                std::numeric_limits<double>::digits10);

    std::complex<double> a(3.0, 4.0), b(1.0, -2.0);
    std::complex<double> sum = a + b, prod = a * b, quot = a / b, cj = std::conj(a);
    std::printf("complex sum %g %g prod %g %g quot %g %g\n", sum.real(), sum.imag(), prod.real(), prod.imag(), quot.real(), quot.imag());
    std::printf("complex abs %g norm %g conj %g %g\n", std::abs(a), std::norm(a), cj.real(), cj.imag());
    std::printf("complex eq %d %d\n", (int)(a == a), (int)(a == b));

    std::mt19937 r(5489);
    std::printf("mt:");
    for (int i = 0; i < 5; i++) std::printf(" %u", r());
    std::printf("\n");
    std::mt19937 r2(1);
    std::printf("dice %u %u %u\n", 1u + r2() % 6u, 1u + r2() % 6u, 1u + r2() % 6u);
    std::printf("bernoulli %d %d\n", (r2() / 4294967296.0) < 0.5, (r2() / 4294967296.0) < 0.5);

    using half = std::ratio<1, 2>;
    using also_half = std::ratio<2, 4>;
    using five_sixths = std::ratio_add<std::ratio<1, 2>, std::ratio<1, 3>>;
    using one_half = std::ratio_multiply<std::ratio<2, 3>, std::ratio<3, 4>>;
    std::printf("ratio %d/%d %d/%d %d/%d %d/%d\n", (int)half::num, (int)half::den, (int)also_half::num, (int)also_half::den,
                (int)five_sixths::num, (int)five_sixths::den, (int)one_half::num, (int)one_half::den);

    auto d = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::milliseconds(1500));
    auto two = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::seconds(2));
    std::printf("chrono %lld %lld %lld %lld\n",
                (long long)d.count(),
                (long long)std::chrono::duration_cast<std::chrono::milliseconds>(d).count(),
                (long long)std::chrono::duration_cast<std::chrono::seconds>(d).count(),
                (long long)two.count());
    return 0;
}

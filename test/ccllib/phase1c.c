/* ccllib phase 1c (CCLLIB.md): <algorithm>, <numeric>, <limits>, <complex>, <random>, <ratio> and <chrono>, built by
   cicilang as C and by cicilang++ as C++, and compared with phase1c.cpp over std::, which clang++ builds. The three
   print phase1c.expect. */
#include <stdio.h>
#include <vector.pl>
#include <algorithm.pl>
#include <numeric.pl>
#include <limits.pl>
#include <complex.pl>
#include <random.pl>
#include <ratio.pl>
#include <chrono.pl>

int main(void) {
    vector<int> v = [int; 5, 3, 9, 1, 3];
    sort(v);
    printf("sort:");
    for (size_t i = 0; i < len(v); i++) printf(" %d", at(v, i));
    printf("\n");
    reverse(v);
    printf("reverse:");
    for (size_t i = 0; i < len(v); i++) printf(" %d", at(v, i));
    printf("\n");
    printf("count=%zu find=%zu min=%zu max=%zu lower=%zu upper=%zu binary=%d\n",
           count(v, 3), find(v, 9), min_element(v), max_element(v), lower_bound(v, 3), upper_bound(v, 3), binary_search(v, 9));
    sort_by(v, a, b, a < b);
    printf("sort_by:");
    for (size_t i = 0; i < len(v); i++) printf(" %d", at(v, i));
    printf("\n");
    printf("tests %d %d %d\n", all_of(v, x, x > 0), any_of(v, x, x > 8), none_of(v, x, x > 10));
    printf("clamp %d %d\n", clamp(12, 0, 9), min(4, 7));
    printf("for_each:");
    for_each(v, x, printf(" %d", x * 2));
    printf("\n");
    printf("filter:");
    filter(v, x, x % 3 == 0, printf(" %d", x));
    printf("\n");
    printf("take:");
    take(v, 2, x, printf(" %d", x));
    printf("\n");
    printf("drop:");
    drop(v, 3, x, printf(" %d", x));
    printf("\n");
    vector<int> w = [int; 1, 2, 3];
    vector<int> u = [int; 1, 2, 3];
    vector<int> t = [int; 1, 2, 4];
    vector<int> w5 = [int; 1, 2, 3, 4, 5];
    printf("equal %d %d lex %d %d\n", equal(w, u), equal(w, t), lexicographical_compare(w, t), lexicographical_compare(t, w));
    vector<int> pv = [int; 5, 3, 9, 1, 3];
    partial_sort(pv, 2);
    printf("partial_sort:");
    for (size_t i = 0; i < 2; i++) printf(" %d", at(pv, i));
    printf("\n");

    printf("accumulate %d %d inner %d\n", accumulate(v, 0), accumulate_by(v, 0, x, acc + x * x), inner_product(v, w5, 0));
    vector<int> ps = [int; 0, 0, 0, 0, 0];
    partial_sum(v, ps);
    printf("partial_sum:");
    for (size_t i = 0; i < len(ps); i++) printf(" %d", at(ps, i));
    printf("\n");
    adjacent_difference(v, ps);
    printf("adjacent:");
    for (size_t i = 0; i < len(ps); i++) printf(" %d", at(ps, i));
    printf("\n");
    iota(ps, 10);
    printf("iota:");
    for (size_t i = 0; i < len(ps); i++) printf(" %d", at(ps, i));
    printf("\n");
    printf("gcd=%d lcm=%d midpoint=%d\n", gcd(18, 24), lcm(6, 8), midpoint(3, 10));

    numeric_limits<int> ni;
    numeric_limits<unsigned> nu;
    numeric_limits<double> nd;
    printf("limits int %d %d %d %d\n", max(ni), min(ni), digits(ni), digits10(ni));
    printf("limits uint %u %u %d %d\n", max(nu), min(nu), is_signed(nu), is_integer(nu));
    printf("limits double %g %g %g %d %d\n", (double)max(nd), (double)min(nd), (double)epsilon(nd), digits(nd), digits10(nd));

    complex<double> a = { 3.0, 4.0 };
    complex<double> b = { 1.0, -2.0 };
    complex<double> sum = a + b;
    complex<double> prod = a * b;
    complex<double> quot = a / b;
    complex<double> cj = conj(a);
    printf("complex sum %g %g prod %g %g quot %g %g\n", real(sum), imag(sum), real(prod), imag(prod), real(quot), imag(quot));
    printf("complex abs %g norm %g conj %g %g\n", abs(a), norm(a), real(cj), imag(cj));
    printf("complex eq %d %d\n", a == a, a == b);

    mt19937<> r;
    seed(r, 5489);
    printf("mt:");
    for (int i = 0; i < 5; i++) printf(" %u", next(r));
    printf("\n");
    seed(r, 1);
    printf("dice %u %u %u\n", uniform_int(r, 1, 6), uniform_int(r, 1, 6), uniform_int(r, 1, 6));
    printf("bernoulli %d %d\n", bernoulli(r, 0.5), bernoulli(r, 0.5));

    ratio<1, 2> half;
    ratio<2, 4> also_half;
    ratio_add<1, 2, 1, 3> five_sixths;
    ratio_multiply<2, 3, 3, 4> one_half;
    printf("ratio %lld/%lld %lld/%lld %lld/%lld %lld/%lld\n", num(half), den(half), num(also_half), den(also_half),
           num(five_sixths), den(five_sixths), num(one_half), den(one_half));

    long long d = millis_of(1500);
    printf("chrono %lld %lld %lld %lld\n", count_of(d), duration_cast_millis(d), duration_cast_seconds(d), count_of(seconds_of(2)));
    return 0;
}

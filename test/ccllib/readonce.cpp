// readonce.cpp: the twin of readonce.c over std::
#include <cstdio>
#include <climits>
#include <vector>
#include <string>
#include <algorithm>
#include <numeric>
static int calls;
static int f() { calls++; return 3; }
static int g(int x) { calls++; return x; }
enum { K = std::max(2, 5), L = std::min(7, 4) };
static int table[std::max(3, 4)];
int main() {
    int i = 0;
    int m = std::min(i++, 10), x = std::max(f(), 1), c = std::clamp(g(12), 0, 9);
    std::printf("min %d %d max %d clamp %d calls %d\n", m, i, x, c, calls);
    std::printf("const %d %d %d\n", K, L, (int)(sizeof table / sizeof table[0]));
    double nan = 0.0 / 0.0;
    std::printf("nan %d %d %d %d\n", std::min(nan, 1.0) != std::min(nan, 1.0), (int)std::min(1.0, nan), std::max(nan, 1.0) != std::max(nan, 1.0), (int)std::max(1.0, nan));
    std::vector<int> v = {1, 3, 3, 5, 8, 13};
    int j = 3; calls = 0;
    int n1 = (int)std::count(v.begin(), v.end(), j++); int n2 = (int)(std::find(v.begin(), v.end(), g(5)) - v.begin()); int n3 = (int)(std::find(v.begin(), v.end(), 7) - v.begin());
    std::printf("count %d %d find %d %d calls %d\n", n1, j, n2, n3, calls);
    j = 3;
    int l1 = (int)(std::lower_bound(v.begin(), v.end(), j++) - v.begin()); int l2 = (int)(std::upper_bound(v.begin(), v.end(), j++) - v.begin()); int l3 = (int)(std::upper_bound(v.begin(), v.end(), 3) - v.begin()); int l4 = (int)std::binary_search(v.begin(), v.end(), j++); int l5 = (int)std::binary_search(v.begin(), v.end(), 4);
    std::printf("lower %d upper %d %d search %d %d j %d\n", l1, l2, l3, l4, l5, j);
    int alg_k = 3, alg_i = 5, alg_n = 13;
    std::printf("names %d %d %d\n", (int)std::count(v.begin(), v.end(), alg_k), (int)(std::find(v.begin(), v.end(), alg_i) - v.begin()), (int)(std::lower_bound(v.begin(), v.end(), alg_n) - v.begin()));
    std::vector<int> r = {2, 5, 2};
    std::replace(r.begin(), r.end(), 2.5, 9.0);
    std::printf("replace %d %d %d\n", r[0], r[1], r[2]);
    int a[3] = {10, 20, 30}, b = 99, k = 0;
    std::swap(a[k++], b);
    std::printf("swap %d %d %d %d %d\n", a[0], a[1], a[2], b, k);
    std::string s = "hello";
    std::printf("accumulate %d %d\n", (int)std::accumulate(s.begin(), s.end(), 0), (int)std::accumulate(v.begin(), v.end(), 0L));
    int p = 18; calls = 0;
    int d1 = std::gcd(p++, 24); int d2 = std::gcd(g(-12), 18); int d3 = std::lcm(g(4), 6);
    std::printf("gcd %d %d %d lcm %d %d %d\n", d1, p, d2, d3, std::lcm(0, 5), (int)std::lcm(6L, 4));
    std::printf("gcd min %lld %d\n", (long long)std::gcd(INT_MIN, 0), calls);
    std::printf("midpoint %d %d %d %d %d\n", std::midpoint(INT_MIN, INT_MAX), std::midpoint(0, 3), std::midpoint(3, 0), std::midpoint(-3, 0), std::midpoint(0, -3));
    unsigned ua = 0, ub = UINT_MAX;
    std::printf("midpoint unsigned %u %u\n", std::midpoint(ua, ub), std::midpoint(ub, ua));
    std::printf("midpoint double %g %g %g %.17g\n", std::midpoint(1.0, 2.0), std::midpoint(1e308, 1.6e308), std::midpoint(-1e308, -1.7e308), std::midpoint(0.1, 0.2));
    std::printf("midpoint float %g\n", (double)std::midpoint(3e38f, 3.2e38f));
    int arr[9]; int *q0 = arr, *q1 = arr + 9;
    std::printf("midpoint pointer %d %d\n", (int)(std::midpoint(q0, q1) - arr), (int)(std::midpoint(q1, q0) - arr));
    int t = 1;
    int mo = std::midpoint(t++, 9);
    std::printf("midpoint once %d %d\n", mo, t);
    return 0;
}

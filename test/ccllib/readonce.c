/* readonce.c (1.6.2): each operand of the value helpers, the searches and the folds read once, as C++ reads an
   argument; C++'s formulas for min, max, clamp, gcd, lcm and midpoint; accumulate in its first value's type, replace's
   old value compared in its own type; a constant stays a constant; names of the program's that the texts' own locals
   had hidden */
#include <stdio.h>
#include <limits.h>
#include <vector.pl>
#include <string.pl>
#include <algorithm.pl>
#include <numeric.pl>
static int calls;
static int f(void) { calls++; return 3; }
static int g(int x) { calls++; return x; }
enum { K = max(2, 5), L = min(7, 4) };
static int table[max(3, 4)];
int main(void) {
    int i = 0;
    int m = min(i++, 10), x = max(f(), 1), c = clamp(g(12), 0, 9);
    printf("min %d %d max %d clamp %d calls %d\n", m, i, x, c, calls);
    printf("const %d %d %d\n", K, L, (int)(sizeof table / sizeof table[0]));
    double nan = 0.0 / 0.0;
    printf("nan %d %d %d %d\n", min(nan, 1.0) != min(nan, 1.0), (int)min(1.0, nan), max(nan, 1.0) != max(nan, 1.0), (int)max(1.0, nan));
    vector<int> v = [int; 1, 3, 3, 5, 8, 13];
    int j = 3; calls = 0;
    int n1 = (int)count(v, j++); int n2 = (int)find(v, g(5)); int n3 = (int)find(v, 7);
    printf("count %d %d find %d %d calls %d\n", n1, j, n2, n3, calls);
    j = 3;
    int l1 = (int)lower_bound(v, j++); int l2 = (int)upper_bound(v, j++); int l3 = (int)upper_bound(v, 3); int l4 = binary_search(v, j++); int l5 = binary_search(v, 4);
    printf("lower %d upper %d %d search %d %d j %d\n", l1, l2, l3, l4, l5, j);
    int alg_k = 3, alg_i = 5, alg_n = 13;
    printf("names %d %d %d\n", (int)count(v, alg_k), (int)find(v, alg_i), (int)lower_bound(v, alg_n));
    vector<int> r = [int; 2, 5, 2];
    replace(r, 2.5, 9.0);
    printf("replace %d %d %d\n", r[0], r[1], r[2]);
    int a[3] = {10, 20, 30}, b = 99, k = 0;
    swap_values(a[k++], b);
    printf("swap %d %d %d %d %d\n", a[0], a[1], a[2], b, k);
    string s = "hello";
    printf("accumulate %d %d\n", (int)accumulate(s, 0), (int)accumulate(v, 0L));
    int p = 18; calls = 0;
    int d1 = gcd(p++, 24); int d2 = gcd(g(-12), 18); int d3 = lcm(g(4), 6);
    printf("gcd %d %d %d lcm %d %d %d\n", d1, p, d2, d3, lcm(0, 5), (int)lcm(6L, 4));
    printf("gcd min %lld %d\n", (long long)gcd(INT_MIN, 0), calls);
    printf("midpoint %d %d %d %d %d\n", midpoint(INT_MIN, INT_MAX), midpoint(0, 3), midpoint(3, 0), midpoint(-3, 0), midpoint(0, -3));
    unsigned ua = 0, ub = UINT_MAX;
    printf("midpoint unsigned %u %u\n", midpoint(ua, ub), midpoint(ub, ua));
    printf("midpoint double %g %g %g %.17g\n", midpoint(1.0, 2.0), midpoint(1e308, 1.6e308), midpoint(-1e308, -1.7e308), midpoint(0.1, 0.2));
    printf("midpoint float %g\n", (double)midpoint(3e38f, 3.2e38f));
    int arr[9]; int *q0 = arr, *q1 = arr + 9;
    printf("midpoint pointer %d %d\n", (int)(midpoint(q0, q1) - arr), (int)(midpoint(q1, q0) - arr));
    int t = 1;
    int mo = midpoint(t++, 9);
    printf("midpoint once %d %d\n", mo, t);
    return 0;
}

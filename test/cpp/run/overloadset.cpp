#include <cstdio>
int twice(int x) { return 2 * x; }
double twice(double x) { return 2.5 * x; }
int apply_i(int (*f)(int), int x) { return f(x); }
double apply_d(double (*f)(double), double x) { return f(x); }
int main() {
    int (*pi)(int) = twice;
    double (*pd)(double) = twice;
    printf("%d %.1f %d %.1f\n", apply_i(twice, 3), apply_d(twice, 2.0), pi(4), pd(4.0));
    return 0;
}

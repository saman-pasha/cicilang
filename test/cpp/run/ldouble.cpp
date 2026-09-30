// long double through libc++ (0.108): a stream inserter, <cmath>'s long double overloads, numeric_limits,
// to_string, and the string conversions the shipped library defines (stold, stoi, stod), named by their symbols
#include <cmath>
#include <cstdio>
#include <iostream>
#include <limits>
#include <string>
int main() {
    long double x = 1.0L / 3;
    std::cout.precision(18);
    std::cout << x << " " << sizeof(long double) << "\n";
    long double y = std::sqrt(2.0L);
    std::printf("%.10Lf %.2Lf\n", y, std::fabs(-y));
    std::printf("%d %d\n", std::numeric_limits<long double>::digits, std::numeric_limits<double>::digits);
    std::string s = std::to_string(2.5L);
    std::printf("%s\n", s.c_str());
    long double z = std::stold("3.25");
    int a = std::stoi("12"); double d = std::stod("2.5");
    std::printf("%.2Lf %d %.1f\n", z * 2, a, d);
    return 0;
}

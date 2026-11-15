// the twin of any.c over std::any and std::bitset (1.1.5): clang++ builds it over libc++, and it prints any.expect, the
// lines that the C build and the C++ build of any.c print
#include <any>
#include <bitset>
#include <cstdio>
#include <string>
#include <utility>
struct point { int x, y; };
int main() {
    std::any a = 5;
    std::any b = 2.5;
    point pt = {1, 2};
    std::any c = pt;
    std::printf("values: %d %g %d %d\n", std::any_cast<int>(a), std::any_cast<double>(b), std::any_cast<point>(c).x,
                std::any_cast<point>(c).y);
    std::any d = a;
    std::printf("clone: %d\n", std::any_cast<int>(d));
    std::swap(a, b);
    std::printf("swap: %g %d\n", std::any_cast<double>(a), std::any_cast<int>(b));
    a.reset();
    std::printf("reset: %d\n", a.has_value());
    std::bitset<8> bits(std::string("10101010"));
    std::printf("bitset: %d\n", bits.any());
    return 0;
}

// An enumerator whose initializer the reader cannot fold is the desugaring's (0.160): a constexpr call took the value after
// the one before it, silently -- A was 0 and B 1 where clang++ has 7 and 8
#include <cstdio>

constexpr int seven() { return 7; }
constexpr long twice(long v) { return v * 2; }
struct Lim { static constexpr int top = 40; };

enum Plain { A = seven(), B, C = A * 3, D = Lim::top + 2, E };
enum class Wide : long { X = twice(21), Y, Z = (long) 2.5L };
namespace n { enum Inner { P = seven() + seven(), Q }; }

int main() {
    char buf[B];
    switch (C) {
    case Plain::C: std::printf("case C\n"); break;
    default: std::printf("default\n"); break;
    }
    std::printf("%d %d %d %d %d %zu\n", A, B, C, D, E, sizeof buf);
    std::printf("%ld %ld %ld %d %d\n", (long) Wide::X, (long) Wide::Y, (long) Wide::Z, n::P, n::Q);
    return 0;
}

// THE SATURATING SUM AND DIFFERENCE (0.227): clang's `__builtin_elementwise_add_sat' and `__builtin_elementwise_sub_sat' over two
// integers of one type, which libc++ 22 writes std::add_sat and std::sub_sat on -- the result of the first operand's type, the
// exact value clamped to its range, signed or unsigned as that type is (LLVM's `llvm.sadd.sat' and kin)
#include <climits>
#include <cstdio>
#include <numeric>
int main() {
    unsigned char a = 200, b = 100;
    signed char c = -100, d = -100;
    std::printf("%d %d %d %d\n", (int) std::add_sat(a, b), (int) std::add_sat(c, d), (int) std::sub_sat(b, a),
                (int) std::sub_sat(c, (signed char) 100));
    std::printf("%d %d %u %lld\n", std::add_sat(INT_MAX, 5), std::sub_sat(INT_MIN, 1), std::sub_sat(3u, 5u), std::add_sat(LLONG_MAX, 1LL));
    short s = 30000;
    std::printf("%d %d\n", (int) std::add_sat(s, (short) 30000), (int) std::add_sat((short) -5, (short) 3));
    int x = INT_MAX - 1, y = 9;
    unsigned u = 7, v = 9;
    std::printf("%d %d %u %u\n", __builtin_elementwise_add_sat(x, y), __builtin_elementwise_sub_sat(-x, y),
                __builtin_elementwise_sub_sat(u, v), __builtin_elementwise_add_sat(u, v));
    return 0;
}

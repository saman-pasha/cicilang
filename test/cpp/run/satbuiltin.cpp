// THE SATURATING SUM AND DIFFERENCE (0.227): clang's `__builtin_elementwise_add_sat' and `__builtin_elementwise_sub_sat' over two
// integers of one type, which libc++ 22 writes std::add_sat and std::sub_sat on -- the result of the first operand's type, the
// exact value clamped to its range, signed or unsigned as that type is (LLVM's `llvm.sadd.sat' and kin)
#include <climits>
#include <cstdio>
#include <numeric>
// C++26'S SATURATION ARITHMETIC BY ITS NAMES (1.6.21): the paper that unified them renamed add_sat, sub_sat, mul_sat,
// div_sat and saturate_cast saturating_add, saturating_sub, saturating_mul, saturating_div and saturating_cast --
// libc++ 23's, __cpp_lib_saturation_arithmetic 202603L, where libc++ 22's 202311L has the old names
#if __cpp_lib_saturation_arithmetic >= 202603L
#define ADD_SAT std::saturating_add
#define SUB_SAT std::saturating_sub
#define MUL_SAT std::saturating_mul
#define DIV_SAT std::saturating_div
#define SAT_CAST std::saturating_cast
#else
#define ADD_SAT std::add_sat
#define SUB_SAT std::sub_sat
#define MUL_SAT std::mul_sat
#define DIV_SAT std::div_sat
#define SAT_CAST std::saturate_cast
#endif
int main() {
    unsigned char a = 200, b = 100;
    signed char c = -100, d = -100;
    std::printf("%d %d %d %d\n", (int) ADD_SAT(a, b), (int) ADD_SAT(c, d), (int) SUB_SAT(b, a),
                (int) SUB_SAT(c, (signed char) 100));
    std::printf("%d %d %u %lld\n", ADD_SAT(INT_MAX, 5), SUB_SAT(INT_MIN, 1), SUB_SAT(3u, 5u), ADD_SAT(LLONG_MAX, 1LL));
    short s = 30000;
    std::printf("%d %d\n", (int) ADD_SAT(s, (short) 30000), (int) ADD_SAT((short) -5, (short) 3));
    int x = INT_MAX - 1, y = 9;
    unsigned u = 7, v = 9;
    std::printf("%d %d %u %u\n", __builtin_elementwise_add_sat(x, y), __builtin_elementwise_sub_sat(-x, y),
                __builtin_elementwise_sub_sat(u, v), __builtin_elementwise_add_sat(u, v));
    return 0;
}

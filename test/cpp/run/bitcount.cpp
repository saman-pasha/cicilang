// The bit counts fold in a constexpr function: the argument is the callee's parameter, the width the builtin's own
// (clz, ctz, popcount: unsigned; l and ll: 64 bits) or, for the g forms, the argument's type; the g forms answer
// their second argument for zero. A static constexpr member that does not fold is an undefined symbol at the link.
#include <cstdio>

template <class T> constexpr int lz(T t) { return __builtin_clzg(t, (int)(sizeof(T) * 8)); }
template <class T> constexpr int tz(T t) { return __builtin_ctzg(t, (int)(sizeof(T) * 8)); }
template <class T> constexpr int pc(T t) { return __builtin_popcountg(t); }
constexpr int lzi(unsigned x) { return __builtin_clz(x); }
constexpr int lzl(unsigned long x) { return __builtin_clzl(x); }
constexpr int tzll(unsigned long long x) { return __builtin_ctzll(x); }
constexpr int tzi(unsigned x) { return __builtin_ctz(x); }
constexpr int pcl(unsigned long x) { return __builtin_popcountl(x); }
template <class T> constexpr int log2_of(T t) { return (int)(sizeof(T) * 8) - 1 - lz(t); }

struct S {
  static constexpr int a = lz(1u);                    // 31
  static constexpr int b = lz((unsigned long)0);      // 64: the fallback
  static constexpr int c = lz((unsigned char)3);      // 6: the type's width is 8
  static constexpr int d = tz(40u);                   // 3
  static constexpr int e = tz((unsigned short)0);     // 16
  static constexpr int f = pc(0xF0F0u);               // 8
  static constexpr int g = lzi(0x00FF0000u);          // 8
  static constexpr int h = lzl(1ul << 40);            // 23
  static constexpr int i = tzll(1ull << 62);          // 62
  static constexpr int j = tzi(96u);                  // 5
  static constexpr int k = pcl(~0ul);                 // 64
  static constexpr int l = log2_of(4096ull);          // 12
  static constexpr int m = lz((unsigned long long)1 << 63);  // 0
};

int main() {
  std::printf("%d %d %d %d %d %d %d\n", S::a, S::b, S::c, S::d, S::e, S::f, S::g);
  std::printf("%d %d %d %d %d %d\n", S::h, S::i, S::j, S::k, S::l, S::m);
  return 0;
}

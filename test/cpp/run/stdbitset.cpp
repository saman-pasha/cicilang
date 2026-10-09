// std::bitset (0.117): the one-word specialization (16 bits) and the multi-word primary (70 bits), whose out-of-class members
// are defined for a PATTERN of the template's arguments (`__bitset<1, _Size>::__bitset()' beside the primary's); construction
// from an unsigned value, set / reset / flip / test, count, any / none / all, the operators, the conversion to unsigned long
#include <bitset>
#include <cstdio>
int main() {
  std::bitset<16> b;
  std::printf("%zu %zu %d %d\n", b.size(), b.count(), (int)b.any(), (int)b.none());
  b.set(3);
  std::printf("%zu %lu\n", b.count(), b.to_ulong());
  b.flip(0);
  std::printf("%zu %lu\n", b.count(), b.to_ulong());
  b.set(5); b.set(7);
  std::printf("%zu %lu %d %d\n", b.count(), b.to_ulong(), (int)b.test(3), (int)b.test(4));
  b.reset(3);
  std::printf("%zu %lu %d\n", b.count(), b.to_ulong(), (int)b[5]);
  std::bitset<16> c(0xF0F0);
  std::printf("%zu %lu\n", c.count(), c.to_ulong());
  std::bitset<16> d = b & c, e = b | c, f = b ^ c, g = ~c;
  std::printf("%lu %lu %lu %lu\n", d.to_ulong(), e.to_ulong(), f.to_ulong(), g.to_ulong());
  std::printf("%d %d %d\n", (int)(b == c), (int)(b != c), (int)(c == std::bitset<16>(0xF0F0)));
  c <<= 4; std::printf("%lu\n", c.to_ulong());
  c >>= 8; std::printf("%lu\n", c.to_ulong());
  std::bitset<16> all; all.set();
  std::printf("%zu %d\n", all.count(), (int)all.all());
  std::bitset<70> w;
  w.set(0); w.set(65); w.set(69);
  std::printf("%zu %d %d %d\n", w.count(), (int)w.test(65), (int)w.test(64), (int)w.any());
  w.flip(65); w.set(33);
  std::printf("%zu %d %d\n", w.count(), (int)w.test(65), (int)w.test(33));
  std::bitset<70> w2 = w << 2;
  std::printf("%zu %d %d\n", w2.count(), (int)w2.test(35), (int)w2.test(2));
  w.reset();
  std::printf("%zu %d\n", w.count(), (int)w.none());
  return 0;
}

// a class value returned where a scalar result is wanted converts through its conversion function ([stmt.return]/2): a proxy
// that converts to bool, as libc++'s bitset::test returns its __bit_const_reference
#include <cstdio>
struct Ref { unsigned v; unsigned m; operator bool() const { return (v & m) != 0; } };
struct Bits {
  unsigned w = 5;
  Ref operator[](unsigned i) const { return Ref{w, 1u << i}; }
  bool test(unsigned i) const { return (*this)[i]; }
  bool test2(unsigned i) const { bool b = (*this)[i]; return b; }
};
template <class T> struct TRef { T v; T m; constexpr operator bool() const noexcept { return (v & m) != 0; } };
template <class T> struct TBits {
  T w = 5;
  TRef<T> operator[](unsigned i) const { return TRef<T>{w, (T)(1u << i)}; }
  bool test(unsigned i) const { return (*this)[i]; }
};
int main() { Bits b; TBits<unsigned> t; std::printf("%d %d %d %d %d\n", (int)b.test(0), (int)b.test(1), (int)b.test2(2), (int)t.test(0), (int)t.test(1)); return 0; }

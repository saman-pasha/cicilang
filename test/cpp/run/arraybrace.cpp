// an array member initialized by a braced list in the constructor's initializer list: `first_{0}' zeroes the array, `n_{5, 6}'
// fills two elements and zeroes the third (libc++'s __bitset), in a class and in a class template, with a typedef'd element
#include <cstdio>
#include <cstddef>
struct A {
  unsigned long first_[4];
  int n_[3];
  A() : first_{0}, n_{5, 6} {}
  unsigned long sum() const { unsigned long t = 0; for (int i = 0; i < 4; i++) t += first_[i]; return t + n_[0] + n_[1] + n_[2]; }
};
template <size_t N> class Base {
public:
  typedef size_t size_type;
  typedef size_type storage_type;
protected:
  storage_type first_[N];
  constexpr Base() noexcept;
  size_t sum() const { size_t t = 0; for (size_t i = 0; i < N; i++) t += first_[i]; return t; }
};
template <size_t N> inline constexpr Base<N>::Base() noexcept : first_{0} {}
template <size_t N> class Bits : public Base<N> {
public:
  constexpr Bits() noexcept {}
  size_t total() const { return Base<N>::sum(); }
};
int main() {
  long junk[16];
  for (int i = 0; i < 16; i++) junk[i] = 0x55AA;
  A a;
  Bits<2> b;
  Bits<9> c;
  std::printf("%lu %zu %zu\n", a.sum(), b.total(), c.total());
  return 0;
}

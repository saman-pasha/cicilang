// A data member whose type names a call of the class's own static constexpr function (libc++'s hh_mm_ss `precision').
#include <cstdio>
template <unsigned long long N> struct Pow { static constexpr unsigned long long value = N; };
template <class D> struct H {
  static constexpr unsigned long long pow10(unsigned e) { unsigned long long r = 1; for (unsigned i = 0; i < e; ++i) r *= 10U; return r; }
  static constexpr unsigned width(unsigned long long n) { return n >= 10 ? 1 + width(n / 10) : 0; }
  static constexpr unsigned fw = width(D::den);
  using precision = Pow<pow10(fw)>;
  precision p_;
  int buf_[pow10(2)];
  int x_ = 7;
};
struct Milli { static constexpr unsigned long long den = 1000; };
int main() { H<Milli> h; std::printf("%d %u %llu %d\n", h.x_, H<Milli>::fw, (unsigned long long) decltype(h.p_)::value, (int) sizeof(h.buf_)); return 0; }

// refwiden: a reference to an arithmetic type bound to an expression of ANOTHER arithmetic type binds a TEMPORARY of
// the referent's type, initialized from the expression ([dcl.init.ref]/5.4). The temporary was as wide as the
// expression, so `const size_t &' handed an int read eight bytes of a four-byte slot -- std::max<size_t>(2 * n, 1), and
// every std::deque that grew, asked for a map of 8589934593 pointers.
#include <algorithm>
#include <cstddef>
#include <cstdio>

size_t id(const size_t &x) { return x; }
double half(const double &x) { return x / 2; }
long widen(long &&x) { return x + 1; }
template <class T> const T &pick(const T &a, const T &b) { return a < b ? b : a; }

struct Cap {
  size_t cap_ = 1;
  size_t capacity() const { return cap_; }
};

int main() {
  const size_t &r = 3;                                    // an int literal bound to a wider unsigned
  int i = 5;
  size_t a = id(3);
  size_t b = id(i);                                       // an int lvalue: a copy, widened
  size_t c = pick<size_t>(3, 2);
  Cap cap;
  size_t d = std::max<size_t>(2 * cap.capacity(), 1);     // the deque's growth
  size_t e = std::max<size_t>(0, 1);
  std::printf("%zu %zu %zu %zu %zu %zu\n", r, a, b, c, d, e);

  const long &w = i;                                      // a COPY of i: a later write to i does not show
  i = 6;
  std::printf("%ld %d\n", w, i);

  std::printf("%g %g\n", half(7), half(i));               // an int to a double
  const int &t = 3.9;                                     // a double to an int truncates
  const double &f = 1.5f;                                 // a float widens
  std::printf("%d %g\n", t, f);

  const unsigned long long &u = -1;                       // the sign extended, then read unsigned
  unsigned char uc = 200;
  const int &z = uc;                                      // zero extended
  const int &ch = 'a';
  std::printf("%llu %d %d\n", u, z, ch);

  const bool &bt = 5;                                     // a bool is 0 or 1, whatever came
  const bool &bf = 0.0;
  std::printf("%d %d\n", (int)bt, (int)bf);

  long &&rr = i;                                          // an rvalue reference binds the converted copy
  rr += 10;
  std::printf("%ld %d %ld\n", rr, i, widen(i));

  long l = 7;
  std::printf("%zu %ld\n", id(l), std::min<long>(i, 9));
  return 0;
}

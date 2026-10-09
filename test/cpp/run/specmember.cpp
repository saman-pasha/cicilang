// the members of a PARTIAL SPECIALIZATION defined out of its class are the specialization's, not the primary's: both define
// `W::W()', `first()', `flip()', `kind()' and `~W()' out of the class, and an instance picked from the specialization takes the
// specialization's (libc++'s __bitset<1, _Size> beside __bitset<_N_words, _Size>, and the explicit __bitset<0, 0>)
#include <cstdio>
#include <cstddef>
template <size_t N, size_t S> class W {
  unsigned long a_[N];
public:
  W();
  unsigned long first() const;
  void flip();
  size_t kind() const;
  ~W();
};
template <size_t N, size_t S> W<N, S>::W() : a_{7} { }
template <size_t N, size_t S> unsigned long W<N, S>::first() const { return a_[0]; }
template <size_t N, size_t S> void W<N, S>::flip() { for (size_t i = 0; i < N; i++) a_[i] = ~a_[i]; }
template <size_t N, size_t S> size_t W<N, S>::kind() const { return 100 + N; }
template <size_t N, size_t S> W<N, S>::~W() { std::printf("~W<%zu,%zu>\n", N, S); }
template <size_t S> class W<1, S> {
  unsigned long a_;
public:
  W();
  unsigned long first() const;
  void flip();
  size_t kind() const;
  ~W();
};
template <size_t S> W<1, S>::W() : a_(3) { }
template <size_t S> unsigned long W<1, S>::first() const { return a_; }
template <size_t S> void W<1, S>::flip() { a_ = ~a_ & ((1ul << S) - 1); }
template <size_t S> size_t W<1, S>::kind() const { return 1; }
template <size_t S> W<1, S>::~W() { std::printf("~W<1,%zu>\n", S); }
template <> class W<0, 0> {
public:
  W() {}
  size_t kind() const { return 0; }
};
int main() {
  W<2, 100> p;
  W<1, 16> s;
  W<0, 0> z;
  p.flip();
  s.flip();
  std::printf("%lu %lu %zu %zu %zu\n", p.first() & 0xFF, s.first(), p.kind(), s.kind(), z.kind());
  return 0;
}

// The implicit default constructor builds a default member initializer with `this' in scope: a constructor template
// deduces its parameter from `this' (C++20), as libc++ 18's `__output_buffer<_CharT> __output_{..., this}' does
#include <cstddef>
#include <cstdio>
template <class C> struct Out {
  template <class T> explicit Out(C *p, std::size_t n, T *o) : n_(n), first_(*p), self_(sizeof(T)) { (void) o; }
  std::size_t n_; C first_; std::size_t self_;
};
template <class C> struct Stor {
  C *begin() { return buf_; }
  static constexpr std::size_t size = 256 / sizeof(C);
  C buf_[size] = {'x'};
};
template <class C> struct Sized {
  Stor<C> s_;
  Out<C> out_{s_.begin(), s_.size, this};
  std::size_t n_{0};
};
int main() {
  Sized<char> z;
  std::printf("%zu %c %zu %zu\n", z.out_.n_, z.out_.first_, z.out_.self_, z.n_);
  return 0;
}

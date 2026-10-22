// A template-id qualified by a namespace names the namespace's template, never the member alias template of the
// class being walked ([basic.lookup.qual]/1): libc++ 22's vector declares an alias `__split_buffer' over
// `std::__split_buffer<_Up, _Alloc, __split_buffer_pointer_layout>'.
#include <cstdio>

namespace ns {
template <class T, class A, int K>
struct Buf {
  T v[K];
  int cap() const { return K; }
};

template <class T>
class Vec {
  template <class U, class A>
  using Buf = ns::Buf<U, A, 3>;

public:
  Buf<T, int> b;
  int cap() const { return b.cap(); }
  static int size() { return sizeof(Buf<T, int>); }
};
} // namespace ns

int main() {
  ns::Vec<long> v;
  std::printf("%d %d\n", v.cap(), ns::Vec<char>::size());
  return 0;
}

// conversion functions defined out of their class: for a class and for a class template, explicit and not, and a conversion
// to the template's own parameter
#include <cstdio>
struct P { long q; operator long() const; explicit operator bool() const; };
P::operator long() const { return q + 5L; }
P::operator bool() const { return q != 0; }
template <class T> struct S { T k; operator int() const; operator T() const; };
template <class T> S<T>::operator int() const { return (int)k + 1; }
template <class T> S<T>::operator T() const { return k * 2; }
int main() {
  P p{3}, z{0};
  long l = p;
  bool b1 = static_cast<bool>(p), b2 = static_cast<bool>(z);
  S<long> s{10};
  int i = s;
  long t = s;
  std::printf("%ld %d %d %d %ld\n", l, (int)b1, (int)b2, i, t);
  return 0;
}

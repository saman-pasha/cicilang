// a friend function defined in the class with declaration-specifiers BEFORE `friend' (libc++ writes
// `_LIBCPP_CONSTEXPR_SINCE_CXX20 friend ...'), in a class and in a class template
#include <cstdio>
struct A {
  int v;
  constexpr friend int operator-(const A &a, const A &b) { return a.v - b.v; }
  inline friend bool operator==(const A &a, const A &b) { return a.v == b.v; }
};
template <class T> struct B {
  T v;
  constexpr friend T operator-(const B &a, const B &b) { return a.v - b.v; }
  constexpr friend int twice(const B &a) { return (int)a.v * 2; }
};
int main() {
  A x{5}, y{2};
  B<long> p{9}, q{4};
  std::printf("%d %d %ld %d\n", x - y, (int)(x == y), p - q, twice(p));
  return 0;
}

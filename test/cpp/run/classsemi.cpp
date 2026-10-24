// a lone `;' among a class's members is an empty-declaration ([class.mem]/1): libc++'s <mdspan> writes one after a member function
#include <cstdio>
struct A {
  int f() const { return 4; };
  ;
  int g() const { return 5; };
};
template <class T> struct B {
  T h() const { return T(6); };
};
int main() {
  A a;
  B<int> b;
  std::printf("%d %d %d\n", a.f(), a.g(), b.h());
  return 0;
}

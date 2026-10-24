// static and virtual members of a class template, declared with their specifiers and defined out of the class
#include <cstdio>
template <class T>
struct X {
  static T twice(T a);
  virtual T f(T a) const;
  virtual ~X() {}
};
template <class T> T X<T>::twice(T a) { return a * 2; }
template <class T> T X<T>::f(T a) const { return a + 1; }
template <class T>
struct Y : X<T> {
  T f(T a) const override { return a + 10; }
};
int main() {
  Y<int> y;
  const X<int> &r = y;
  std::printf("%d %d %d\n", X<int>::twice(21), r.f(5), y.X<int>::f(5));
  return 0;
}

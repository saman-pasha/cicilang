// A function template declared twice, the default of its SFINAE parameter on the first declaration only, the two overloads told apart
// by the condition (libc++ 21's complex operator*): the definition takes the default its declaration gives.
#include <cstdio>
#include <type_traits>
template <class T> struct cx {
  T re, im;
  cx(T r, T i) : re(r), im(i) {}
};
template <class T, std::enable_if_t<std::is_floating_point<T>::value, int> = 0> cx<T> operator*(const cx<T> &a, const cx<T> &b);
template <class T, std::enable_if_t<!std::is_floating_point<T>::value, int> = 0> cx<T> operator*(const cx<T> &a, const cx<T> &b);
template <class T, std::enable_if_t<std::is_floating_point<T>::value, int>> cx<T> operator*(const cx<T> &a, const cx<T> &b) {
  return cx<T>(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re);
}
template <class T, std::enable_if_t<!std::is_floating_point<T>::value, int>> cx<T> operator*(const cx<T> &a, const cx<T> &b) {
  return cx<T>(a.re * b.re, a.im * b.im);
}
template <class T> cx<T> operator*(const cx<T> &a, const T &k) { return cx<T>(a.re * k, a.im * k); }
template <class T> cx<T> operator*(const T &k, const cx<T> &a) { return cx<T>(a.re * k, a.im * k); }
int main() {
  cx<double> a(1, 2), b(3, -1);
  cx<double> c = a * b;
  cx<int> i(2, 3), j(4, 5);
  cx<int> k = i * j;
  cx<double> d = a * 2.0, e = 3.0 * b;
  std::printf("%g %g %d %d %g %g %g %g\n", c.re, c.im, k.re, k.im, d.re, d.im, e.re, e.im);
  return 0;
}

// a static data member of a class TEMPLATE defined out of its class, with an initializer (0.117): `template <class T, int N> const int It<T, N>::bs = N * 2;'
// while the class declares `static const int bs;' -- libc++'s __deque_iterator::__block_size. Each instance takes the initializer as its own
// default (cpp_static_defs), so it folds; a non-const static, `T W<T>::zero = T()', is defined too
#include <cstdio>
template <class T, int N> struct It { static const int bs; T v; int get() const { return bs + N; } };
template <class T, int N> const int It<T, N>::bs = N * 2;
template <class T> struct W { static const long big; static T zero; };
template <class T> const long W<T>::big = sizeof(T) * 10;
template <class T> T W<T>::zero = T();
int main() {
  It<int, 8> a; a.v = 1;
  std::printf("%d %d\n", a.get(), It<char, 3>::bs);
  std::printf("%ld %ld %d\n", W<int>::big, W<char>::big, (int)W<short>::zero);
  return 0;
}

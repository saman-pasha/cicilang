// of two members that tie on their parameters, the one whose trailing requires-clause holds wins ([over.match.best]/2.6)
#include <cstdio>
template <class T, class U> struct same { static constexpr bool value = false; };
template <class T> struct same<T, T> { static constexpr bool value = true; };
template <class A, class B> struct R {
  int end() const { return 1; }
  int end() const requires same<A, B>::value { return 2; }
  int f(int) { return 10; }
  int f(int) requires (sizeof(A) == 4) && (sizeof(B) == 4) { return 20; }
};
int main() {
  R<int, int> a; R<int, long> b;
  std::printf("%d %d %d %d\n", a.end(), b.end(), a.f(0), b.f(0));
  return 0;
}

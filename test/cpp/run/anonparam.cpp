// An unnamed by-value parameter of a class with a destructor: the object is destroyed all the same.
#include <cstdio>
struct T {
  int k;
  explicit T(int v) : k(v) { std::printf("make %d\n", k); }
  T(const T &o) : k(o.k + 10) { std::printf("copy %d\n", k); }
  ~T() { std::printf("drop %d\n", k); }
};
int skip(T) { return 7; }
int both(T a, T, int n) { return a.k + n; }
int main() {
  int r = skip(T(1));
  std::printf("r %d\n", r);
  T x(2);
  int s = both(x, T(3), 4);
  std::printf("s %d\n", s);
  return 0;
}

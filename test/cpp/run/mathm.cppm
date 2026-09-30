module;
#include <cstdio>
export module mathm;
import basem;
export int square(int x) { return x * x; }
export struct Acc {
  int total;
  Acc() : total(0) {}
  void add(int v) { total += v; }
};
int hidden(int x) { return x + 1; }
export int bump(int x) { return twice(hidden(x)); }
export {
  int cube(int x) { return x * x * x; }
  template <class T> T biggest(T a, T b) { return a < b ? b : a; }
}
export void hello() { printf("hello from mathm\n"); }

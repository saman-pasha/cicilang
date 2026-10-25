// A temporary of a statement is destroyed where it was built when an exception leaves the statement, the last built
// first, and never where it was not built (0.207): a temporary bound to a reference parameter was never destroyed by the
// unwinding, and a by-value argument's was the callee's.
#include <cstdio>
struct T {
  int v;
  T(int x) : v(x) { std::printf("T %d\n", v); }
  ~T() { std::printf("~T %d\n", v); }
};
int use(const T &a, const T &b) { if (b.v == 2) throw 7; return a.v + b.v; }
int byval(T a, T b) { if (b.v == 2) throw 8; return a.v + b.v; }
int boom(int x) { if (x) throw 9; return 0; }
int main() {
  try { int r = use(T(1), T(2)); std::printf("r %d\n", r); } catch (int e) { std::printf("caught %d\n", e); }
  try { use(T(3), T(2)); } catch (int e) { std::printf("caught %d\n", e); }
  try { byval(T(4), T(2)); } catch (int e) { std::printf("caught %d\n", e); }
  try { use(T(5), T(boom(1))); } catch (int e) { std::printf("caught %d\n", e); }
  int r2 = use(T(6), T(7));
  std::printf("r2 %d\n", r2);
  int r3 = byval(T(8), T(9));
  std::printf("r3 %d\n", r3);
}

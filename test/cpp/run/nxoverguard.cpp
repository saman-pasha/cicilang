// A FREE FUNCTION'S NOEXCEPT IS ITS DEFINITION'S OWN (0.232): `void f(double)' beside `void f(int) noexcept' throws to its
// caller's handler -- the name's set guarded every overload of the name by terminate -- and a function template's overload
// alike; the plain call of the noexcept one, under a try, runs it; and a static member and a deallocation called there
#include <cstdio>
void f(int) noexcept {}
void f(double d) { if (d > 0) throw 1; }
template <class T> void t(T *) noexcept {}
template <class T> void t(T v) { if (v > 0) throw 2; }
struct S { static int s(int v) noexcept { return v + 1; } };
static void g(long v) noexcept { std::printf("g %ld\n", v); }
static int h(int v) { if (v > 1) throw v; return v; }
int main() {
  try { f(1); f(1.5); } catch (int e) { std::printf("caught f %d\n", e); }
  int k = 0;
  try { t(&k); t(3); } catch (int e) { std::printf("caught t %d\n", e); }
  try { g(2); std::printf("s %d\n", S::s(4)); int *p = new int(5); delete p; h(3); } catch (int e) { std::printf("caught h %d\n", e); }
  std::printf("%d %d\n", (int) noexcept(f(1)), (int) noexcept(f(1.5)));
  return 0;
}

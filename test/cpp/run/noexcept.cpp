// noexcept kept on a function (0.110): the operator asks the callee, and an exception leaving a noexcept function
// calls std::terminate without running the destructors on the way
#include <cstdio>
int f(int x) { return x + 1; }
int g(int x) noexcept { return x + 2; }
int h(int x) noexcept(false) { return x; }
int k(int x) throw() { return x; }
struct G { const char *n; ~G() { printf("~G %s\n", n); fflush(stdout); } };
struct S {
  int m() { return 1; }
  int n() const noexcept { return 2; }
  int p(int x) noexcept;
};
int thrower(int x) { if (x > 2) throw x; return x; }
int S::p(int x) noexcept { return thrower(x); }
int safe(int x) noexcept { G g{"safe"}; return thrower(x) + 1; }
int main() {
  S s;
  printf("%d %d %d %d\n", (int) noexcept(f(1)), (int) noexcept(g(1)), (int) noexcept(h(1)), (int) noexcept(k(1)));
  printf("%d %d\n", (int) noexcept(s.m()), (int) noexcept(s.n()));
  printf("%d %d %d\n", (int) noexcept(1 + 2), (int) noexcept(f(1) + g(2)), (int) noexcept(g(f(1))));
  try { printf("%d\n", thrower(1)); thrower(5); } catch (int e) { printf("caught %d\n", e); }
  printf("%d %d\n", safe(1), s.p(2));
  fflush(stdout);
  safe(7);
  printf("not reached\n");
  return 0;
}

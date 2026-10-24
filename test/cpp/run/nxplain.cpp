// The terminate guard (0.199): a function template declared noexcept, and a noexcept function and method that throw with
// no call -- each calls std::terminate where an exception would leave it; each case runs in a child process of its own
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <sys/wait.h>
#include <unistd.h>
template <class T> void t(T v) noexcept { if (v > 0) throw (int) v; }
void d(int v) noexcept { if (v > 0) throw v; }
struct M { void m(int v) noexcept { if (v > 0) throw v; } };
template <class T> void ok(T v) noexcept { if (v < 0) throw (int) v; }
static void run(int k) {
  std::fflush(stdout);
  pid_t p = fork();
  if (p == 0) {
    std::set_terminate([] { std::puts("terminate"); std::fflush(stdout); std::_Exit(0); });
    try {
      if (k == 0) t(1);
      else if (k == 1) d(1);
      else if (k == 2) M{}.m(1);
      else { ok(1); std::puts("returned"); }
    } catch (int e) { std::printf("caught %d\n", e); }
    std::fflush(stdout);
    std::_Exit(0);
  }
  int st = 0;
  waitpid(p, &st, 0);
}
int main() {
  std::printf("%d %d %d %d\n", (int) noexcept(t(1)), (int) noexcept(d(1)), (int) noexcept(M{}.m(1)), (int) noexcept(ok(1)));
  for (int k = 0; k < 4; ++k) run(k);
}

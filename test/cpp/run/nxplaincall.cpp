// A CALL OF A NOEXCEPT CALLEE IS A PLAIN CALL (0.232), and every noexcept boundary terminates where an exception would
// leave it ([except.spec]/5): a constructor's member initializer, a destructor that says nothing (implicitly noexcept), a
// class template's member -- each case in a child process of its own; a destructor that says noexcept(false) throws on
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <sys/wait.h>
#include <unistd.h>
static int boom(int v) { if (v > 0) throw v; return v; }
struct C { int v; C(int k) noexcept : v(boom(k)) {} };
struct E { int n; ~E() { if (n > 0) throw n; } };
struct F { int n; ~F() noexcept(false) { if (n > 0) throw n; } };
template <class T> struct Box { T t; void put(T v) noexcept { t = (T) boom((int) v); } };
struct G { int n; ~G() { std::printf("~G%d\n", n); } };
static int quiet(int v) noexcept { return v * 2; }
static void run(int k) {
  std::fflush(stdout);
  pid_t p = fork();
  if (p == 0) {
    std::set_terminate([] { std::puts("terminate"); std::fflush(stdout); std::_Exit(0); });
    try {
      if (k == 0) { C c(1); std::printf("built %d\n", c.v); }
      else if (k == 1) { E e{1}; }
      else if (k == 2) { Box<long> b{0}; b.put(3); }
      else if (k == 3) { F f{4}; }
      else { G g{5}; std::printf("quiet %d\n", quiet(21)); C c(0); std::printf("built %d\n", c.v); }
    } catch (int e) { std::printf("caught %d\n", e); }
    std::fflush(stdout);
    std::_Exit(0);
  }
  int st = 0;
  waitpid(p, &st, 0);
}
int main() {
  for (int k = 0; k < 5; ++k) run(k);
  return 0;
}

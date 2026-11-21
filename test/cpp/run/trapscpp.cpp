// THE TRAPS IN C++ (1.6.10): __builtin_trap(), __builtin_verbose_trap(category, message) and __builtin_debugtrap() in a
// try, in a noexcept function, in a template, in a lambda, and in a constexpr function's arm that a constant evaluation
// does not take; a trap that the program reaches stops a child of its own, whose handler of the trap's signal leaves
// with a status of its own. A verbose trap's message may be a conditional over a template's argument.
#include <csignal>
#include <cstdio>
#include <sys/wait.h>
#include <unistd.h>

constexpr int f(int x) { return x > 0 ? x : (__builtin_trap(), 0); }
static_assert(f(3) == 3);

template <class T> T must(T x) { if (!x) __builtin_verbose_trap("trapscpp", "zero"); return x; }
template <int N> int sized() { if (N > 5) __builtin_verbose_trap("trapscpp", N > 9 ? "big" : "small"); return N; }
static void never() noexcept { __builtin_verbose_trap("trapscpp", "noexcept"); }
static void on_trap(int) { _exit(7); }

static int stopped(int k) {
  pid_t c = fork();
  if (c == 0) {
    std::signal(SIGILL, on_trap); std::signal(SIGTRAP, on_trap);
    switch (k) {
    case 0: __builtin_trap(); break;
    case 1: __builtin_verbose_trap("trapscpp", "the child stops"); break;
    case 2: __builtin_debugtrap(); break;
    case 3: never(); break;
    case 4: (void)must(0); break;
    case 5: (void)sized<7>(); break;
    case 6: { volatile int z = 0; (void)f(z); break; }
    case 7: { auto chk = [](int v) { if (v > 9) __builtin_trap(); return v; }; (void)chk(10); break; }
    default: (void)must(k); break;
    }
    _exit(0);
  }
  int st = 0;
  waitpid(c, &st, 0);
  return WIFEXITED(st) && WEXITSTATUS(st) == 7;
}

int main(int argc, char **) {
  int caught = 0;
  try { if (argc > 5) __builtin_trap(); throw 7; } catch (int k) { caught = k; }
  auto chk = [](int v) { if (v > 9) __builtin_trap(); return v + 1; };
  std::printf("%d %d %d %.1f %d %d\n", caught, f(argc + 4), must(3), must(2.5), sized<2>(), chk(argc));
  std::printf("%d %d %d\n", __has_builtin(__builtin_trap), __has_builtin(__builtin_verbose_trap), __has_builtin(__builtin_debugtrap));
  for (int k = 0; k < 9; k++) std::printf("%d", stopped(k));
  std::printf("\n");
  return 0;
}

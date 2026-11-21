/* THE TRAPS (1.6.10): __builtin_trap() and clang 19's __builtin_verbose_trap(category, message) stop the program, and
   __builtin_debugtrap() signals it. Each case stops a child of its own, whose handler of the two signals a trap gives
   (SIGILL on x86-64, SIGTRAP on aarch64) leaves with a status of its own: no core is written and no crash is reported.
   A trap that the program does not reach costs nothing: in a statement, at a function's end, in a switch's default, in a
   loop, in an arm of a conditional -- the first of a void one too --, of && and of ||, and __builtin_unreachable() in an
   arm; and a trap in both arms of one conditional. A verbose trap's arguments are constant strings: literals, a cast of
   one, `__func__', a literal moved by a constant, one read up to its first null character. Each was `undeclared'. */
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(e) ((e) ? (void)0 : ((void)"check failed: " #e, __builtin_trap()))

static int f(int x) { if (x > 0) return x; __builtin_trap(); }
static int kind(int n) { switch (n) { case 0: return 10; case 1: return 11; default: __builtin_trap(); } }
static int pick(int n) { for (int i = 0; ; i++) { if (i == n) return i * 2; if (i > 100) __builtin_trap(); } }
static int check(int v) { if (v > 9) __builtin_verbose_trap("traps", "too big"); return v + 1; }
static int named(int v) {
  if (v < 0) __builtin_verbose_trap(__func__, "abc" + 1);
  if (v > 99) __builtin_verbose_trap("traps", &"xyz"[2]);
  if (v == 50) __builtin_verbose_trap((const char *)"traps", "cast");
  if (v == 51) __builtin_verbose_trap("traps", "cut\0$");
  return v * 3;
}

static void on_trap(int s) { (void)s; _exit(7); }

static const char *ended(int k) {
  pid_t c = fork();
  if (c == 0) {
    signal(SIGILL, on_trap); signal(SIGTRAP, on_trap);
    switch (k) {
    case 0: __builtin_trap(); break;
    case 1: __builtin_verbose_trap("traps", "the child stops"); break;
    case 2: __builtin_debugtrap(); break;
    case 3: CHECK(k == 4); break;
    case 4: (void)f(-1); break;
    case 5: (void)kind(7); break;
    case 6: (void)check(10); break;
    case 7: { int y = k > 0 ? (__builtin_trap(), 1) : 2; printf("%d\n", y); break; }
    case 8: (void)named(-1); break;
    case 9: (void)named(100); break;
    case 10: { int y = k > 0 ? (__builtin_trap(), 1) : (__builtin_trap(), 2); printf("%d\n", y); break; }
    default: (void)named(k); break;
    }
    _exit(0);
  }
  int st = 0;
  waitpid(c, &st, 0);
  return WIFEXITED(st) ? (WEXITSTATUS(st) == 7 ? "trapped" : "exited") : "signalled";
}

int main(int argc, char **argv) {
  (void)argv;
  printf("%d %d %d %d %d %d\n", f(3), kind(0), kind(1), pick(4), check(argc), named(argc));
  int y = argc > 0 ? 5 : (__builtin_trap(), 7);
  int w = argc < 0 ? (__builtin_trap(), 1) : 9;
  int a = argc > 0 && (argc < 9 || (__builtin_trap(), 0));
  int b = argc > 5 && (__builtin_trap(), 1);
  int c = argc < 5 || (__builtin_trap(), 1);
  int u = argc > 0 ? 6 : (__builtin_unreachable(), 8);
  CHECK(argc > 0);
  argc > 99 ? __builtin_trap() : (void)0;
  printf("%d %d %d %d %d %d\n", y, w, a, b, c, u);
  printf("%d %d %d\n", __has_builtin(__builtin_trap), __has_builtin(__builtin_verbose_trap), __has_builtin(__builtin_debugtrap));
  for (int k = 0; k < 12; k++) printf("%s%s", k ? " " : "", ended(k));
  printf("\n");
  return 0;
}

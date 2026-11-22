/* A CALL THAT DOES NOT RETURN, AND A LOOP THAT DOES NOT END, END A PATH OF THE SAFE PART (1.6.15). A block that ends in a
   call of a function declared not to return -- glibc's exit, abort, _Exit and quick_exit, a program's _Noreturn function
   and its __attribute__((noreturn)) one, declared before its definition -- or in a trap, with new memory still live in
   it, ends the program there, and nothing is asked of that memory: each such block runs in a child of its own, and the
   parent prints how the child ended. A loop with no condition, or whose condition is a constant other than zero, ends by
   its breaks alone: a function whose loop only a return leaves has no path past the loop. A cast of such a call to void, a
   comma that makes it, and a conditional whose two arms end, end their path too. A pointer to exit keeps the function's
   type, its mark aside, and so does a constructor's function. Each case was refused, `plain pointer not consumed'. */
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

_Noreturn static void die(int c) { exit(c); }
static void fatal(int c) __attribute__((noreturn));
__attribute__((constructor)) static void boot(void) { }

static jmp_buf env;

static int first_over(const int *v, int n, int k) {
  char *seen = malloc(16);
  if (!seen) return -1;
  for (int i = 0;; i++) {
    seen[i % 16] = 1;
    if (i == n || v[i] > k) { int r = i; free(seen); return r; }
  }
}

static int halve(int x) {
  char *t = malloc(4);
  if (!t) return -1;
  while (1) {
    t[0] = (char)x;
    if (x < 10) { free(t); return x; }
    x /= 2;
  }
}

static int steps(int x) {
  char *t = malloc(4);
  if (!t) return -1;
  int n = 0;
  do {
    t[0] = (char)n;
    if (++n == x) { free(t); return n; }
  } while (1);
}

static int sign(int x) {
  char *t = malloc(4);
  if (!t) return 0;
  t[0] = 1;
  if (x > 0) { int r = t[0]; free(t); return r; }
  else if (x < 0) { free(t); return -1; }
  free(t);
  if (x == 0) return 0;
  abort();
}

static void ended(int k) {
  fflush(stdout);
  pid_t c = fork();
  if (c == 0) {
    char *live = malloc(32);
    if (!live) _exit(99);
    live[0] = 'x';
    switch (k) {
    case 0: exit(10); break;
    case 1: abort(); break;
    case 2: _Exit(12); break;
    case 3: quick_exit(13); break;
    case 4: die(14); break;
    case 5: fatal(15); break;
    case 6: __builtin_trap(); break;
    case 7: { char *more = malloc(8); if (more) more[0] = 0; exit(17); } break;
    case 8: (void)exit(18); break;
    case 9: { char *more = malloc(8); (free(more), exit(19)); } break;
    case 10: k > 2 ? exit(20) : abort(); break;
    case 11: (exit(21), (void)live[0]); break;
    default: __builtin_unreachable();
    }
  }
  int st = 0;
  waitpid(c, &st, 0);
  if (WIFEXITED(st)) printf("case %d: exit %d\n", k, WEXITSTATUS(st));
  else if (WIFSIGNALED(st)) printf("case %d: signal %s\n", k, WTERMSIG(st) == SIGABRT ? "abort" : WTERMSIG(st) == SIGILL || WTERMSIG(st) == SIGTRAP ? "trap" : "other");
}

int main(void) {
  for (int k = 0; k < 12; k++) ended(k);
  int v[] = {1, 4, 9, 16};
  printf("%d %d %d %d\n", first_over(v, 4, 5), halve(80), steps(3), sign(5));
  printf("%d %d\n", sign(-2), sign(0));
  void (*f)(int) = exit;
  void (*g)(void) = abort;
  printf("%d %d %d %d\n", f != 0 && g != 0, _Generic(exit, void (*)(int): 1, default: 0), __builtin_types_compatible_p(__typeof__(die), void (int)), _Generic(boot, void (*)(void): 1, default: 0));
  if (setjmp(env) == 0) {
    char *w = malloc(5);
    if (!w) return 1;
    free(w);
    longjmp(env, 1);
  }
  puts("back from longjmp");
  return 0;
}

static void fatal(int c) { exit(c); }

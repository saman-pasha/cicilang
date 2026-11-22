/* A FUNCTION WHOSE BODY RETURNS NEVER ENDS ITS CALLER'S PATH (1.6.17): a function not declared not to return, whose body
   holds no return, no goto and no label, and whose end no path reaches -- a call of exit, abort or such a function, an if
   whose two branches end so, a loop that no break leaves, a do-while whose body ends so or that never ends, a cast of such
   a call to void, a comma that makes one, a continue that stays in its loop, a break that an inner loop -- a for, a while,
   a do -- or a switch catches, a call of one defined after it --, is found by the safe part, and a block that ends in a call of
   it with new memory live is no leak: each case runs in a child of its own, and the parent prints how it ended. Each was
   refused, `plain pointer not consumed', since the check read no function's body for it */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static void die(int c) { fflush(stdout); exit(c); }
static void fatal(int c) { if (c > 40) die(c); else abort(); }
static void spin(int c) { for (;;) { if (c) die(c); } }
static void dodie(int c) { do { die(c); } while (c); }
static void wrapped(int c) { { int k = c * 2; (void)k; } (void)fflush(stdout); (fflush(stdout), exit(c)); }
static void counted(int c) { for (int i = 0; ; i++) { if (i < c) continue; die(c); } }
static void forever(int c) { while (1) { c++; if (c > 1000) die(44); } }
static void late_die(int c);
static void early(int c) { late_die(c); }
static void late_die(int c) { die(c); }
static void nested(int c) { while (1) { for (int i = 0; ; i++) { if (i > c) break; } die(c); } }
static void switched(int c) { for (;;) { switch (c) { case 1: break; default: break; } if (c > 0) die(c); } }
static void nestwhile(int c) { while (c > 0) { if (c == 3) break; c--; } die(c); }
static void nestdo(int c) { do { if (c) break; } while (0); die(c); }
static void dospin(int c) { do { if (c > 100) die(c); c++; } while (1); }

static int first(int x) {
  char *t = malloc(4);
  if (!t) return -1;
  t[0] = (char)x;
  if (x > 0) { int r = t[0]; free(t); return r; }
  die(9);
}

static void ended(int k) {
  fflush(stdout);
  pid_t c = fork();
  if (c == 0) {
    char *live = malloc(32);
    if (!live) _exit(99);
    live[0] = 'x';
    switch (k) {
    case 0: die(40); break;
    case 1: fatal(41); break;
    case 2: fatal(1); break;
    case 3: spin(43); break;
    case 4: dodie(44); break;
    case 5: wrapped(45); break;
    case 6: counted(46); break;
    case 7: forever(0); break;
    case 8: early(48); break;
    case 9: nested(49); break;
    case 10: switched(50); break;
    case 11: nestwhile(52); break;
    case 12: nestdo(53); break;
    case 13: dospin(54); break;
    default: { char *more = malloc(8); if (more) more[0] = 0; die(51); }
    }
  }
  int st = 0;
  waitpid(c, &st, 0);
  if (WIFEXITED(st)) printf("case %d: exit %d\n", k, WEXITSTATUS(st));
  else if (WIFSIGNALED(st)) printf("case %d: signal %s\n", k, WTERMSIG(st) == SIGABRT ? "abort" : "other");
}

int main(void) {
  for (int k = 0; k < 15; k++) ended(k);
  printf("%d\n", first(7));
  return 0;
}

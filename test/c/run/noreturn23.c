/* C23'S SPELLINGS OF A FUNCTION THAT DOES NOT RETURN (1.6.15; C23 6.7.12.7): `[[noreturn]]', its old spelling
   `[[_Noreturn]]', GCC's `[[gnu::noreturn]]', and <stddef.h>'s `unreachable()'. A block that ends in such a call with
   new memory live in it ends the program there, in a child of its own; each case was refused, `plain pointer not
   consumed'. */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

[[noreturn]] static void stop(int c) { exit(c); }
[[_Noreturn]] static void stop2(int c) { exit(c + 1); }
[[gnu::noreturn]] static void stop3(int c) { exit(c + 2); }

static int level(int x) {
  char *t = malloc(4);
  if (!t) return -1;
  switch (x) {
  case 1: free(t); return 10;
  case 2: free(t); return 20;
  default: unreachable();
  }
}

static void ended(int k) {
  fflush(stdout);
  pid_t c = fork();
  if (c == 0) {
    char *live = malloc(32);
    if (!live) _exit(99);
    live[0] = 'x';
    if (k == 0) { char *m = malloc(2); (void)m; stop(20); }
    if (k == 1) { char *m = malloc(2); (void)m; stop2(20); }
    if (k == 2) { char *m = malloc(2); (void)m; stop3(20); }
    _exit(98);
  }
  int st = 0;
  waitpid(c, &st, 0);
  printf("case %d: exit %d\n", k, WIFEXITED(st) ? WEXITSTATUS(st) : -1);
}

int main(void) {
  for (int k = 0; k < 3; k++) ended(k);
  printf("%d %d\n", level(1), level(2));
  return 0;
}

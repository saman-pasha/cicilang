/* A LONGJMP THAT THE SAFE PART FOLLOWS (1.6.17): the frames it leaves hold no live memory and no defer, and the frames it
   lands in hold each pointer as the setjmp saw it -- a buffer live across the setjmp and freed after the jump, a jump from
   a callee two calls deep, a buffer handed by parameter, sigsetjmp and siglongjmp, a jump from a nested block whose
   frame holds no owner, a second setjmp of the same buffer, a buffer handed down two calls, a function's own buffer, a
   local named as a function that may jump, a setjmp in a loop whose owner changes between the rounds, a pointer given a
   value on a path that returns after the second return, a pointer given a call's value where the call may jump before
   the store -- one that holds no memory, and a borrow --, an own
   field given new memory through a pointer, functions that set a global buffer themselves -- by an if's, a switch's or a
   while's condition, a statement, a declaration -- and catch their own jumps, a function whose setjmp of its own buffer
   is in a branch, a longjmp whose argument ends the program; each prints as clang's build */
#define _POSIX_C_SOURCE 200809L
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static jmp_buf on_error;
static int depth;
static void fail(const char *m) { printf("error: %s\n", m); longjmp(on_error, 1); }
static int parse(const char *s) {
  int n = 0;
  for (; *s; s++) {
    if (*s == '(') depth++;
    else if (*s == ')') { if (--depth < 0) fail("unbalanced"); }
    n++;
  }
  return n;
}
static int nest(const char *s) { return parse(s) + 1; }
static int shade(int x) { int fail = x + 1; return fail; }
static void jump_to(jmp_buf e, int v) { longjmp(e, v); }
static void jump_via(jmp_buf e, int v) { jump_to(e, v); }
static int self_jump(void) { jmp_buf own_env; if (setjmp(own_env)) return 1; longjmp(own_env, 1); }
static jmp_buf loop_env;
static void maybe_jump(int i) { if (i == 1) longjmp(loop_env, 1); }
static sigjmp_buf senv;
static void sjump(void) { siglongjmp(senv, 3); }
static int guarded(const char *s) {
  const char *at = s;
  if (setjmp(on_error)) { at = NULL; return -1; }
  return nest(at);
}
static char *make_line(int bad) { if (bad) fail("bad line"); char *l = malloc(8); if (l) l[0] = 'L'; return l; }
static int timed(int bad) {
  char *line = NULL;
  if (setjmp(on_error)) return -3;
  line = make_line(bad);
  if (!line) return -4;
  int c = line[0];
  free(line);
  return c;
}
static int skip_word(const char *s) { if (*s == '!') fail("bang"); int i = 0; while (s[i] && s[i] != ' ') i++; return s[i] ? i + 1 : i; }
static int first_word(const char *text) {
  const char *cur = text;
  if (setjmp(on_error)) return -10;
  cur = text + skip_word(cur);
  return (int)(cur - text);
}
struct box { own char *data; };
static int refill(struct box *b, const char *s) {
  if (setjmp(on_error)) return -5;
  free(b->data);
  b->data = malloc(4);
  return nest(s);
}
static int by_switch(const char *s) { switch (setjmp(on_error)) { case 0: return nest(s); default: return -6; } }
static int by_while(const char *s) { volatile int tries = 0; while (setjmp(on_error) != 0) { if (++tries > 1) return -7; } return nest(s); }
static int by_stmt(const char *s) { volatile int jumped = 0; setjmp(on_error); if (jumped) return -8; jumped = 1; return nest(s); }
static int by_decl(const char *s) { volatile int r = setjmp(on_error); if (r) return -9; return nest(s); }
static int nested_own(int c) {
  jmp_buf mine;
  if (c) {
    if (setjmp(mine)) return 1;
    longjmp(mine, 1);
  }
  return 0;
}
static int caught_all(void) {
  char *t = malloc(4);
  if (!t) return 0;
  depth = 0;
  int a = by_switch("())");
  depth = 0;
  int b = by_while("())");
  depth = 0;
  int c = by_stmt("())");
  depth = 0;
  int d = by_decl("())");
  int e = nested_own(1);
  free(t);
  return a + b + c + d + e;
}
static void dead_arg(void) { jmp_buf mine; if (setjmp(mine)) return; fflush(stdout); longjmp(mine, ({ _exit(0); 1; })); }

int main(void) {
  char *buf = malloc(32);
  if (!buf) return 1;
  buf[0] = 'b';
  int r = 0;
  if (setjmp(on_error) == 0) { r = nest("(a(b))"); r += nest("x))"); }
  else r = -1;
  printf("%d %d %c\n", r, depth, buf[0]);
  depth = 0;
  if (setjmp(on_error) == 0) r = nest("((()))");
  else r = -2;
  printf("%d\n", r);
  jmp_buf local;
  volatile int v = setjmp(local);
  if (v == 0) jump_to(local, 7);
  int s = sigsetjmp(senv, 1);
  if (s == 0) sjump();
  volatile int n = 0;
  if (setjmp(on_error) < 3) {
    n++;
    { int k = n; if (k < 5) longjmp(on_error, k + 1); }
  }
  volatile int w = setjmp(local);
  if (w == 0) jump_via(local, 9);
  int t = self_jump() + shade(-1);
  char *q = NULL;
  int jumps = 0;
  for (int i = 0; i < 3; i++) {
    if (setjmp(loop_env) == 0) maybe_jump(i);
    else jumps++;
    free(q);
    q = malloc(2);
  }
  free(q);
  printf("%d %d %d %d %d %d %c\n", v, s, n, w, t, jumps, buf[0]);
  free(buf);
  depth = 0;
  int g = guarded("())");
  depth = 0;
  int m = timed(1) * 1000 + timed(0);
  int fw = first_word("ab cd") * 100 + first_word("!x");
  struct box bx;
  bx.data = malloc(4);
  depth = 0;
  int f = refill(&bx, "())");
  free(bx.data);
  printf("%d %d %d %d\n", g, m, fw, f);
  printf("%d\n", caught_all());
  dead_arg();
  return 0;
}

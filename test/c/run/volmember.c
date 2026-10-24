#include <setjmp.h>
#include <stdio.h>
/* a member of a volatile object is volatile (C 6.5.2.3/3), a bitfield's too: across a longjmp its value is the one stored
   (7.13.2.1/3), and every store and load is made */
struct S { int a; unsigned b : 4; int c[2]; };
static jmp_buf jb;
static void jump(void) { longjmp(jb, 1); }
static int count(volatile struct S *p) { int n = 0; for (int i = 0; i < 3; i++) { p->a = p->a + 1; n += p->a; } return n; }
int main(void) {
  volatile struct S s = { 1, 2, { 3, 4 } };
  if (setjmp(jb) == 0) { s.a = 10; s.b = 5; s.c[1] = 40; jump(); }
  printf("%d %u %d %d\n", s.a, s.b, s.c[0], s.c[1]);
  printf("%d %d\n", count(&s), s.a);
  return 0;
}

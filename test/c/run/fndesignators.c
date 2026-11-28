/* Function designators (1.6.57; C17 6.3.2.1/4, 6.5.3.2/4): `*' of a pointer to a function is the function, whose value is its
   address again, so that `(*p)(3)', `(**p)(4)', `(*getp(1))(2)' and `(*h.fp)(7)' call what p, getp's result and the member hold
   -- the first loaded from the function's code and called what it read, the second was refused -- built as C and as C++ */
#include <stdio.h>
static int f(int x) { return x + 1; }
static int g(int x) { return x * 3; }
struct H { int (*fp)(int); };
static int apply(int (*h)(int), int v) { return (*h)(v) + (***h)(v); }
static int (*getp(int k))(int) { return k ? g : f; }
static int (*tab[2])(int) = { f, g };
int main(void) {
  int (*p)(int) = g; struct H h = { f }; struct H *ph = &h;
  int (*q)(int) = *p; int (*r)(int) = &*p; int (*s)(int) = *f; int (*t)(int) = **f;
  printf("%d %d %d %d %d %d\n", (*f)(1), (**f)(2), q(3), r(4), s(5), t(6));
  printf("%d %d %d %d\n", (*h.fp)(7), (*ph->fp)(8), apply(*p, 2), apply(&f, 3));
  printf("%d %d %d %d %d\n", p == *p, *p == g, (*getp(1))(2), (*getp(0))(2), (*tab[1])(5) + (**tab[0])(5));
  return 0;
}

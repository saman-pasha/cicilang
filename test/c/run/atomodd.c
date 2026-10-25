/* an _Atomic struct of a size that is no lock-free width: every operation atomic, through libatomic's generic routines, and a failed
   compare-exchange writes the value it found to *expected (C17 7.17.7.4/2) -- gcc's output: clang 18 leaves *expected as it was, and
   clang 21 fails the first exchange too, over the padding of the sixteen bytes it rounds the struct to */
#include <stdio.h>
#include <stdatomic.h>
#include <string.h>
struct S3 { char c[3]; };
struct S12 { int i[3]; };
struct S20 { char c[20]; };
_Atomic struct S20 g;
int main(void) {
  _Atomic struct S3 a; struct S3 v = {{1, 2, 3}};
  atomic_store(&a, v);
  struct S3 w = atomic_load(&a);
  printf("%d %d %d\n", w.c[0], w.c[1], w.c[2]);
  struct S20 u; memset(&u, 7, sizeof u);
  atomic_store(&g, u);
  struct S20 z = atomic_load(&g);
  struct S20 n; memset(&n, 9, sizeof n);
  struct S20 o = atomic_exchange(&g, n);
  struct S20 r = g;
  printf("%d %d %d %d %d\n", z.c[0], z.c[19], o.c[5], r.c[0], (int) atomic_is_lock_free(&g));
  struct S12 e = {{1, 2, 3}}, d = {{4, 5, 6}}, f = {{7, 8, 9}};
  _Atomic struct S12 c = e;
  int ok = atomic_compare_exchange_strong(&c, &e, d);
  int no = atomic_compare_exchange_strong(&c, &f, e);
  struct S12 q = atomic_load(&c);
  printf("%d %d %d %d %d | %d %d %d\n", ok, no, q.i[0], q.i[1], q.i[2], f.i[0], f.i[1], f.i[2]);
  c = e;
  q = c;
  printf("%d %d %d\n", q.i[0], q.i[1], q.i[2]);
  return 0;
}

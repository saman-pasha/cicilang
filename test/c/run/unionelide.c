/* BRACE ELISION INTO A STRUCT OR A UNION MEMBER (C 6.7.9/20; 0.194): a member that is a struct or a union, given a scalar,
   takes the items its own members need -- glibc's struct sigaction begins with a union -- locally and in a global */
#include <stdio.h>
#include <signal.h>
#include <string.h>
struct Q { int a, b; };
struct P { struct Q q; int c; };
union U { int i; float f; };
struct H { union U u; int k; };
struct P gp = {1, 2, 3};
struct H gh = {4, 5};
int main(void) {
  struct sigaction sa = {0};
  struct P p = {1, 2, 3};
  struct H h = {6, 7};
  struct P p2 = {{8, 9}, 10};
  int arr[2][2] = {1, 2, 3, 4};
  printf("%d %d %d %d %d %d %d %d %d\n", sa.sa_flags, p.q.a, p.q.b, p.c, h.u.i, h.k, gp.q.b, gh.u.i, gh.k);
  printf("%d %d %d %d %d\n", p2.q.b, p2.c, arr[0][1], arr[1][0], arr[1][1]);
  return 0;
}

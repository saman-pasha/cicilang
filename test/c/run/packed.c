#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/epoll.h>
/* GCC's packed attribute (clang reads it): a struct's members at alignment 1, a member's alone, a struct's own
   alignment; glibc's struct epoll_event is packed on x86-64 */
struct __attribute__((packed)) P { char c; int i; short s; };
struct Q { char c; int i __attribute__((packed)); char d; };
struct __attribute__((packed, aligned(4))) R { char c; int i; };
struct H { char c; struct P p; };
static int sum(struct P p) { return p.c + p.i + p.s; }
int main(void) {
  struct P a[2] = { { 1, 2, 3 }, { 4, 5, 6 } };
  struct P *pp = &a[1];
  printf("%zu %zu %zu\n", sizeof(struct P), offsetof(struct P, i), offsetof(struct P, s));
  printf("%zu %zu %zu\n", sizeof(struct Q), offsetof(struct Q, i), offsetof(struct Q, d));
  printf("%zu %zu\n", sizeof(struct R), _Alignof(struct R));
  printf("%zu %zu %zu\n", sizeof(struct H), offsetof(struct H, p), sizeof a);
  pp->i = 70000; pp->s = -2;
  printf("%d %d %d %d\n", a[1].i, a[1].s, sum(a[0]), sum(*pp));
  unsigned char raw[sizeof a];
  memcpy(raw, a, sizeof a);
  printf("%d %d\n", raw[7], raw[8]);
  printf("%zu %zu\n", sizeof(struct epoll_event), offsetof(struct epoll_event, data));
  return 0;
}

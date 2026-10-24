#include <cstdio>
// a function's result tied to a reference parameter (cicilang's `tie'): the caller's pointer borrows the argument's
// object (0.202: `plain pointer not consumed'); the expect is clang++'s, the program without the tie
struct Arena { char buf[256]; unsigned long used = 0; };
char *at(Arena &a) tie a { return a.buf + a.used; }
void *at2(unsigned long n, Arena &a) tie a { void *p = a.buf + a.used; a.used += n; return p; }
int main() {
  Arena ar;
  char *p = at(ar);
  void *q = at2(8, ar);
  std::printf("%d %d\n", p == ar.buf, (char *) q == ar.buf);
  return 0;
}

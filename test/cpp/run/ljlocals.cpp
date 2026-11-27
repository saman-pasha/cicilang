// ljlocals.cpp (1.6.27): longjmps out of frames that hold C++ locals declared with an initializer, which run nothing --
// a callee's, deeper than the setjmp's, and a callee's of a buffer that its caller set -- and a block's between the setjmp
// and the jump: the mark of such a local is a goto's and a case label's alone (1.6.26's ck_runs_defer/1), and 1.6.25
// refused each as a longjmp over a defer
#include <csetjmp>
#include <cstdio>
static std::jmp_buf env;
static void deeper(int k) { int x = k * 2; std::longjmp(env, x); }
static void through(std::jmp_buf &b, int k) { int y = k + 1; std::longjmp(b, y); }
int main() {
  volatile int seen = 0;
  int r = setjmp(env);
  if (r == 0) { int z = 3; deeper(z); }
  seen = seen + r;
  std::jmp_buf mine;
  int s = setjmp(mine);
  if (s == 0) through(mine, 6);
  std::printf("%d %d %d\n", r, s, (int)seen);
  return 0;
}

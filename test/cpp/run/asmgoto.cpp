// GNU's `asm goto' in C++ (0.231), a callbr: in a function whose local has a destructor, the label in the local's own
// scope, so the jump leaves no scope and the destructor runs once, at the return, on both paths; a member function's
// asm goto with an output and a label by its name. A jump that leaves a destructor's scope is refused, as clang++
// refuses it (the driver gate)
#include <cstdio>

struct Noisy {
  int id;
  ~Noisy() { std::printf("~%d\n", id); }
};

static int stay(int x) {
  Noisy n{x};
  int r = 1;
#if defined(__x86_64__)
  asm goto("testl %0, %0; jz %l1" : : "r"(x) : "cc" : zero);
#elif defined(__aarch64__)
  asm goto("cbz %w0, %l1" : : "r"(x) : "cc" : zero);
#endif
  std::printf("nonzero %d\n", x);
  return r;
zero:
  r = 0;
  return r;
}

struct Box {
  int v;
  int get() const {
    int y;
#if defined(__x86_64__)
    asm goto("movl %1, %0; testl %1, %1; jz %l[empty]" : "=r"(y) : "r"(v) : "cc" : empty);
#elif defined(__aarch64__)
    asm goto("mov %w0, %w1; cbz %w1, %l[empty]" : "=r"(y) : "r"(v) : "cc" : empty);
#endif
    return y + 100;
  empty:
    return y - 100;
  }
};

int main() {
  std::printf("%d\n", stay(0));
  std::printf("%d\n", stay(3));
  Box a{0}, b{5};
  std::printf("%d %d\n", a.get(), b.get());
  return 0;
}

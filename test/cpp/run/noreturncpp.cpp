// A CALL THAT DOES NOT RETURN, AND A LOOP THAT DOES NOT END, END A PATH OF THE SAFE PART, IN C++ (1.6.15): a block that
// ends in `std::exit', `std::abort', `std::_Exit', `std::quick_exit', `std::terminate', a `[[noreturn]]' function -- free,
// a member defined in its class, a static member declared there and defined after it -- or GCC's `noreturn', with new
// memory live in it, ends the program there, in a child of its own; an object with a destructor is not destroyed by
// `exit'. A `[[noreturn]]' function that throws is caught as any. `while (true)' and `for (;;)' end by their breaks alone.
// A pointer and a reference to `std::exit' keep its type. Each case was refused, `plain pointer not consumed'.
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <sys/wait.h>
#include <unistd.h>

[[noreturn]] static void die(int c) { std::exit(c); }
__attribute__((noreturn)) static void fatal(int c);

struct Bail {
  [[noreturn]] void now(int c) { std::exit(c); }
  [[noreturn]] static void later(int c);
};
void Bail::later(int c) { std::exit(c + 1); }

struct Loud { int v; ~Loud() { std::printf("~Loud %d\n", v); } };

[[noreturn]] static void bounce(int c) { throw c; }

static int caught(int x) {
  int *p = new int(x);
  try {
    if (x > 3) bounce(x);
  } catch (int e) { delete p; return -e; }
  int r = *p;
  delete p;
  return r;
}

static int halve(int x) {
  int *t = new int(0);
  while (true) {
    *t = x;
    if (x < 10) { int r = *t; delete t; return r; }
    x /= 2;
  }
}

static int first(int n) {
  int *t = new int(0);
  for (int i = 0;; i++) {
    *t = i;
    if (i * i >= n) { int r = *t; delete t; return r; }
  }
}

static void ended(int k) {
  std::fflush(stdout);
  pid_t c = fork();
  if (c == 0) {
    int *live = new int(k);
    Loud l{k};
    Bail b;
    switch (*live) {
    case 0: std::exit(30); break;
    case 1: std::abort(); break;
    case 2: std::_Exit(32); break;
    case 3: std::quick_exit(33); break;
    case 4: die(34); break;
    case 5: fatal(35); break;
    case 6: b.now(36); break;
    case 7: Bail::later(36); break;
    default: std::terminate();
    }
  }
  int st = 0;
  waitpid(c, &st, 0);
  if (WIFEXITED(st)) std::printf("case %d: exit %d\n", k, WEXITSTATUS(st));
  else if (WIFSIGNALED(st)) std::printf("case %d: signal\n", k);
}

int main() {
  for (int k = 0; k < 9; k++) ended(k);
  std::printf("%d %d %d %d\n", caught(2), caught(7), halve(80), first(10));
  void (*f)(int) = std::exit;
  void (&r)(int) = std::exit;
  std::printf("%d %d\n", f != nullptr, &r == f);
  Loud end{99};
  return 0;
}

static void fatal(int c) { std::exit(c); }

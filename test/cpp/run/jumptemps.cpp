// jumps past what the desugaring declares (1.6.25): a statement's temporaries, a range-for's own locals and a
// class value's temporary before a later case label or a goto's label are no locals of the program's, so the jumps that
// clang++ takes build -- a C++ local with an initializer or a destructor marks its frame, and such a jump is refused
#include <cstdio>
#include <initializer_list>
struct D { int k; D(int x) : k(x) {} ~D() { std::printf("~D %d\n", k); } int v() { return k; } };
struct S { int v; };
S mk(int x) { return S{x}; }
int main(int argc, char **) {
  int r = 0;
  switch (argc) {
    case 1: r = D(2).v();
    case 2: r += mk(3).v;
    case 3: for (int i : {1, 2}) r += i;
    case 4: r += 1; break;
  }
  if (argc > 7) goto out;
  r += S{4}.v;
out:
  std::printf("%d\n", r);
  return 0;
}

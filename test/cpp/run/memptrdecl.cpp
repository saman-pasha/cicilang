// decltype of a call through a pointer to member function is the member's declared result, its reference kept
// ([dcl.type.decltype]): an lvalue reference result can be assigned through, by hand and through std::invoke
#include <cstdio>
#include <functional>
#include <type_traits>
struct S { int x = 1; int &get() { return x; } int val() const { return x; } };
struct P { int y = 2; virtual int &ref() { return y; } virtual ~P() {} };
int main() {
  S s; P p;
  int &(S::*pm)() = &S::get;
  int (S::*pv)() const = &S::val;
  int &(P::*pr)() = &P::ref;
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype((s.*pm)()), int &>, (int) std::is_same_v<decltype((s.*pv)()), int>,
              (int) std::is_same_v<decltype((p.*pr)()), int &>);
  (s.*pm)() = 5;
  std::invoke(pm, s) += 2;
  std::invoke(pr, p) = 9;
  std::printf("%d %d %d\n", s.x, std::invoke(pv, s), p.y);
  return 0;
}

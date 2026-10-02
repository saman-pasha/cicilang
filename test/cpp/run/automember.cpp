// A member function with an `auto' parameter is a member function template ([dcl.fct]/22), as libc++ 18's
// format-spec parser writes `__get_width(auto &__ctx) const' -- alone, and beside a written template head.
#include <cstdio>
struct ctx { int arg(int i) const { return i * 2; } };
struct ctx2 { int arg(int i) const { return i * 3; } };
struct parser {
  int w = 5;
  int get(auto &c) const { return c.arg(w); }
  template <class T> int both(T t, const auto &c) const { return (int) t + c.arg(1); }
};
int main() {
  ctx c;
  ctx2 d;
  parser p;
  std::printf("%d %d %d\n", p.get(c), p.get(d), p.both(10, d));
  return 0;
}

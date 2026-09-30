// a constructor template's constraint names the class's own static member: it is walked in its class (0.110)
#include <cstdio>
#include <utility>
template <class T> static int pick(std::pair<T, T>) { return 9; }
template <class R> struct holder {
  R v;
  static void __fun(R &);
  static void __fun(R &&) = delete;
  template <class T> requires requires { __fun(std::declval<T>()); }
  holder(T &&t) : v(t) {}
  int get() const { return v; }
};
template <class R> holder(R &) -> holder<R>;
int main() { int x = 4; holder h(x); std::printf("%d\n", h.get()); return 0; }

// A class argument converts to a class parameter through a constructor TEMPLATE whose parameter deduces
// from it ([over.match.copy], [over.ics.user]) -- in a template's acceptance too: libc++'s vformat takes
// format_args, which make_format_args's store converts to through `template <class... A> basic_format_args(
// const __format_arg_store<C, A...> &)'.
#include <cstdio>
template <class C, class... A> struct store { int n = sizeof...(A); };
template <class C> struct args {
  int n;
  template <class... A> args(const store<C, A...> &s) : n(s.n) {}
};
struct ctx {};
struct other {};
template <class = void> int vf(int k, args<ctx> a) { return k + a.n; }
template <class = void> int vf(int k, int a) { return k - a; }
template <class... A> store<ctx, A...> make(A &...) { return store<ctx, A...>{}; }
template <class... A> int fmt(A... xs) { return vf(10, make(xs...)); }
int main() {
  std::printf("%d %d\n", fmt(1, 2), fmt(1, 2, 3));
  return 0;
}

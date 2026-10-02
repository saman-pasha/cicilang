// A parameter whose template parameters are all given explicitly takes no part in deduction ([temp.deduct.call]/4):
// its argument converts, as libc++ 18's `__vformat_to_n<format_context>(..., make_format_args(...))' (C++20)
#include <cstdio>
struct Ctx {};
template <class C, class... Ts> struct Store { int n = sizeof...(Ts); };
template <class C> struct Args {
  int n;
  template <class... Ts> Args(const Store<C, Ts...> &s) : n(s.n) {}
};
template <class C, class... Ts> Store<C, Ts...> make(Ts...) { return {}; }
template <class C, class Out> int vfn(Out o, Args<C> a) { return o * 10 + a.n; }
int main() {
  std::printf("%d\n", vfn<Ctx>(4, make<Ctx>(1, 2.0, 'c')));
  return 0;
}

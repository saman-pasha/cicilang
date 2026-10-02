// a constructor template's parameter names the class's own template parameter: Args<wchar_t> takes no Store<char, ...>
#include <cstdio>
template <class C, class... A> struct Store { int n; };
template <class C> struct Args {
  int k;
  template <class... A> Args(const Store<C, A...> &s) : k(s.n) {}
};
template <class = void> int f(const char *, Args<char> a) { return 100 + a.k; }
template <class = void> int f(const char *, Args<wchar_t> a) { return 200 + a.k; }
int main() {
  Store<char, int, double> s{5};
  std::printf("%d\n", f("x", s));
  Store<wchar_t, int> w{7};
  std::printf("%d\n", f("y", w));
  return 0;
}

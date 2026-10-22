// A constraint and a concept's body see no caller's local ([temp.constr]): libc++ 22's `views::zip_transform'
// names its parameter `__fun', and ref_view's constructor requires `__fun(std::declval<_Tp>())' of its own static.
#include <cstdio>
#include <utility>

struct S {
  int x;
};

template <class R>
struct view {
  int v;
  static void __fun(R &);
  static void __fun(R &&) = delete;
  template <class T>
    requires requires { __fun(std::declval<T>()); }
  view(T &&t) : v(t.x * 3) {}
};

void probe(int);
template <class T>
concept probeable = requires(T t) { probe(t); };

template <class F, class R>
int run(F &&__fun, R &r) {
  view<R> vw(r);
  return __fun(vw.v);
}

template <class F>
int g(F &&probe) {
  return probeable<int> ? probe(S{5}) : -1;
}

int main() {
  S s{4};
  std::printf("%d %d\n", run([](int a) { return a * 2; }, s), g([](S a) { return a.x + 1; }));
  return 0;
}

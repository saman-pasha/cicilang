// A requires-expression's own parameter pack is expanded like a function's, so its requirements never find a variable of the
// function around them under the pack's name (libc++ 21's std::invocable, asked inside __try_constant_folding(..., __args)).
#include <cstdio>
#include <functional>
#include <utility>

template <class F, class... Args>
concept callable_with = requires(F &&f, Args &&...args) { std::invoke(std::forward<F>(f), std::forward<Args>(args)...); };

struct Eq {
  bool operator()(char a, char b) const { return a == b; }
};
struct Holder {
  int v;
  Holder(int x) : v(x) {}
  ~Holder() {}
};

int pick(Holder args) {
  if constexpr (callable_with<Eq &, char &, char &>)
    return args.v + 1;
  else
    return -args.v;
}

template <class T>
int pick_t(T args) {
  auto probe = [&] { return callable_with<Eq &, char &, char &> ? args.v + 10 : -args.v; };
  return probe();
}

int main() {
  std::printf("%d %d\n", pick(Holder(4)), pick_t(Holder(5)));
  std::printf("%d %d %d\n", (int)callable_with<Eq &, char &, char &>, (int)callable_with<Eq &, Holder &, char &>, (int)callable_with<Eq &, char &>);
  return 0;
}

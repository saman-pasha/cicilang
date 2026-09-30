// the promise through a std::coroutine_traits specialization, constructed from the parameters, and unhandled_exception (0.110)
#include <coroutine>
#include <cstdio>
struct Res { int v; };
template <class... A> struct std::coroutine_traits<Res, A...> {
  struct promise_type {
    int v = 0;
    promise_type() {}
    promise_type(int a, int b) : v(a * 100 + b) { printf("promise(%d, %d)\n", a, b); }
    Res get_return_object() { return Res{v}; }
    std::suspend_never initial_suspend() noexcept { return {}; }
    std::suspend_never final_suspend() noexcept { return {}; }
    void return_void() {}
    void unhandled_exception() { printf("unhandled in promise\n"); }
  };
};
Res make(int a, int b) { printf("body %d %d\n", a, b); co_return; }
Res boom(int a, int b) { printf("boom\n"); if (a > 0) throw a; co_return; }
int main() {
  Res r = make(3, 4);
  printf("%d\n", r.v);
  Res q = boom(1, 2);
  printf("%d\n", q.v);
  return 0;
}

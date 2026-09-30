#include <coroutine>
#include <cstdio>
struct Eager {
  int v;
  struct promise_type {
    int *out;
    int keep = 0;
    Eager get_return_object() { return Eager{5}; }
    std::suspend_never initial_suspend() { return {}; }
    std::suspend_never final_suspend() noexcept { return {}; }
    void return_value(int x) { keep = x; printf("return %d\n", x); }
    void unhandled_exception() {}
  };
};
struct Ready {
  bool await_ready() { return true; }
  void await_suspend(std::coroutine_handle<>) {}
  int await_resume() { return 4; }
};
Eager run(int a) {
  int b = co_await Ready{};
  co_return a + b;
}
int main() {
  Eager e = run(3);
  printf("%d\n", e.v);
  return 0;
}

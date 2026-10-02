// operator co_await, a member and a free one (0.110)
#include <coroutine>
#include <cstdio>
struct Task {
  struct promise_type {
    int v = 0;
    Task get_return_object() { return Task{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_never initial_suspend() noexcept { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    void return_value(int x) { v = x; }
    void unhandled_exception() { printf("unhandled\n"); v = -1; }
  };
  std::coroutine_handle<promise_type> h;
  ~Task() { if (h) h.destroy(); }
  int get() { return h.promise().v; }
};
struct Ten {
  struct Aw {
    bool await_ready() { return true; }
    void await_suspend(std::coroutine_handle<>) {}
    int await_resume() { return 10; }
  };
  Aw operator co_await() { return Aw{}; }
};
struct Twenty {};
struct Aw20 { bool await_ready() { return true; } void await_suspend(std::coroutine_handle<>) {} int await_resume() { return 20; } };
Aw20 operator co_await(Twenty) { return Aw20{}; }
Task compute() {
  int a = co_await Ten{};
  int b = co_await Twenty{};
  co_return a + b + 1;
}
int main() {
  Task t = compute();
  printf("%d\n", t.get());
  return 0;
}

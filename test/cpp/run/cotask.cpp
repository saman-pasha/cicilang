#include <coroutine>
#include <cstdio>
struct Noisy {
  int id;
  Noisy(int i) : id(i) { printf("make %d\n", id); }
  ~Noisy() { printf("drop %d\n", id); }
};
struct Task {
  struct promise_type {
    int result = 0;
    std::coroutine_handle<> cont;
    Task get_return_object() { return Task{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_always initial_suspend() { return {}; }
    struct Final {
      bool await_ready() noexcept { return false; }
      std::coroutine_handle<> await_suspend(std::coroutine_handle<promise_type> h) noexcept {
        if (h.promise().cont) return h.promise().cont;
        return std::noop_coroutine();
      }
      void await_resume() noexcept {}
    };
    Final final_suspend() noexcept { return {}; }
    void return_value(int v) { result = v; }
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
  ~Task() { if (h) h.destroy(); }
  bool await_ready() { return false; }
  std::coroutine_handle<> await_suspend(std::coroutine_handle<> c) { h.promise().cont = c; return h; }
  int await_resume() { return h.promise().result; }
};
struct Skip {
  bool go;
  bool await_ready() { return false; }
  bool await_suspend(std::coroutine_handle<>) { return go; }
  int await_resume() { return 7; }
};
Task leaf(int x) {
  Noisy n(x);
  co_return x * 10;
}
Task mid(int x) {
  int a = co_await leaf(x);
  Skip s{false};
  int b = co_await s;
  int c = co_await leaf(x + 1);
  co_return a + b + c;
}
struct Gen {
  struct promise_type {
    int cur = 0;
    Gen get_return_object() { return Gen{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_never initial_suspend() { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    std::suspend_always yield_value(int v) { cur = v; return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
  ~Gen() { if (h) h.destroy(); }
};
Gen forever() {
  Noisy guard(99);
  for (int i = 0;; i++) co_yield i;
}
int main() {
  Task t = mid(1);
  t.h.resume();
  printf("result %d done %d\n", t.h.promise().result, (int) t.h.done());
  {
    Gen g = forever();
    printf("first %d\n", g.h.promise().cur);
    g.h.resume();
    g.h.resume();
    printf("third %d\n", g.h.promise().cur);
  }
  printf("end\n");
  return 0;
}

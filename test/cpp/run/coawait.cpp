#include <coroutine>
#include <cstdio>
struct Val {
  int v;
  bool await_ready() { return true; }
  void await_suspend(std::coroutine_handle<>) {}
  int await_resume() { return v; }
};
struct Job {
  struct promise_type {
    int sum = 0;
    Job get_return_object() { return Job{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_always initial_suspend() { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    Val await_transform(int x) { return Val{x * 2}; }
    Val await_transform(Val v) { return v; }
    std::suspend_always await_transform(std::suspend_always s) { return s; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
  ~Job() { if (h) h.destroy(); }
};
Job work() {
  Val a{5};
  int x = co_await a;
  int y = co_await 21;
  co_await std::suspend_always{} ;
  printf("x %d y %d\n", x, y);
}
int main() {
  Job j = work();
  j.h.resume();
  printf("after first\n");
  j.h.resume();
  printf("done %d\n", (int) j.h.done());
  auto lam = [](int n) -> Job { printf("lambda %d\n", n); co_return; };
  Job k = lam(3);
  k.h.resume();
  return 0;
}

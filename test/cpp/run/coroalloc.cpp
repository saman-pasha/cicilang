#include <coroutine>
#include <cstdio>
#include <cstdlib>
#include <new>
// a coroutine's state through its promise type's allocation functions ([dcl.fct.def.coroutine]/9-12): `operator new' over the
// frame's size and the coroutine's arguments, else over the size alone; the sized `operator delete' where the promise has it;
// `get_return_object_on_allocation_failure', whose call the coroutine returns where the allocation answers null
struct Gen {
  struct promise_type {
    int value = 0;
    static void *operator new(std::size_t n) { std::printf("promise new %d\n", n > 0); return std::malloc(n); }
    static void operator delete(void *p, std::size_t n) { std::printf("promise delete %d\n", n > 0); std::free(p); }
    Gen get_return_object() { return Gen{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_always initial_suspend() noexcept { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    std::suspend_always yield_value(int v) { value = v; return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
  ~Gen() { if (h) h.destroy(); }
};
Gen count(int n) { for (int i = 0; i < n; ++i) co_yield i; }
struct Arena { char buf[1024]; std::size_t used = 0; };
struct Task {
  struct promise_type {
    static void *operator new(std::size_t n, Arena &a, int k) { std::printf("arena new %d\n", k); void *p = a.buf + a.used; a.used += (n + 15) & ~(std::size_t) 15; return p; }
    static void operator delete(void *) { std::printf("arena delete\n"); }
    Task get_return_object() { return Task{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_never initial_suspend() noexcept { return {}; }
    std::suspend_never final_suspend() noexcept { return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
};
Task run(Arena &a, int k) { std::printf("run %d\n", k); co_return; }
static bool fail_alloc;
struct Lazy {
  struct promise_type {
    static void *operator new(std::size_t n) noexcept { std::printf("lazy new\n"); return fail_alloc ? nullptr : std::malloc(n); }
    static void operator delete(void *p) { std::printf("lazy delete\n"); std::free(p); }
    static Lazy get_return_object_on_allocation_failure() { std::printf("failure\n"); return Lazy{nullptr}; }
    Lazy get_return_object() { return Lazy{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_never initial_suspend() noexcept { return {}; }
    std::suspend_never final_suspend() noexcept { return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
};
Lazy lazy() { std::printf("lazy body\n"); co_return; }
int main() {
  {
    Gen g = count(3);
    while (!g.h.done()) { g.h.resume(); if (!g.h.done()) std::printf("%d\n", g.h.promise().value); }
  }
  Arena a;
  run(a, 5);
  std::printf("%d\n", a.used > 0);
  lazy();
  fail_alloc = true;
  Lazy z = lazy();
  std::printf("%d\n", z.h == nullptr);
  return 0;
}

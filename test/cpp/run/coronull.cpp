#include <coroutine>
#include <cstdio>
#include <cstddef>
#include <new>
struct G {
  struct promise_type {
    promise_type() { std::puts("promise built"); }
    ~promise_type() { std::puts("promise destroyed"); }
    static void *operator new(std::size_t) noexcept { std::puts("alloc fails"); return nullptr; }
    static void operator delete(void *) noexcept { std::puts("delete"); }
    static G get_return_object_on_allocation_failure() { std::puts("failure object"); return G{nullptr}; }
    G get_return_object() { return G{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_always initial_suspend() noexcept { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
};
G co() { std::puts("body"); co_return; }
int main() { G g = co(); std::printf("%d\n", g.h ? 1 : 0); return 0; }

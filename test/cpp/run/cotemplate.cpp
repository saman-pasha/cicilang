#include <coroutine>
#include <cstdio>
template <class T> struct Gen {
  struct promise_type {
    T cur{};
    Gen get_return_object() { return Gen{std::coroutine_handle<promise_type>::from_promise(*this)}; }
    std::suspend_always initial_suspend() { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    std::suspend_always yield_value(T v) { cur = v; return {}; }
    void return_void() {}
    void unhandled_exception() {}
  };
  std::coroutine_handle<promise_type> h;
  ~Gen() { if (h) h.destroy(); }
  bool next() { h.resume(); return !h.done(); }
  T value() { return h.promise().cur; }
};
Gen<double> halves(int n) {
  double x = 1.0;
  for (int i = 0; i < n; i++) { co_yield x; x /= 2; }
}
template <class T> Gen<T> repeat(T v, int n) {
  while (n-- > 0) co_yield v;
}
int main() {
  Gen<double> g = halves(4);
  while (g.next()) printf("%g\n", g.value());
  Gen<int> r = repeat(7, 3);
  int s = 0;
  while (r.next()) s += r.value();
  printf("%d\n", s);
  return 0;
}

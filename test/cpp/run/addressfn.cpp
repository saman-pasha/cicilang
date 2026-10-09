// A FUNCTION given to a `T &' (or `const T &') parameter deduces the function type ([temp.deduct.call]/2: no function-to-pointer
// conversion for a reference parameter): std::addressof(f) is a pointer to the function, and libc++ 21's std::thread hands
// std::addressof(__thread_proxy<_Gp>) to its thread-creating function.
#include <cstdio>
#include <memory>
#include <type_traits>
template <class T> void *proxy(void *p) { return p; }
int twice(int x) { return 2 * x; }
template <class T> struct Kind { static const char *name() { return "other"; } };
template <class R, class... A> struct Kind<R(A...)> { static const char *name() { return "function"; } };
template <class T> const char *kind_of(T &) { return Kind<T>::name(); }
template <class T> const char *kind_of_c(const T &) { return Kind<T>::name(); }
template <class T> const char *kind_of_v(T) { return Kind<typename std::remove_pointer<T>::type>::name(); }
template <class T> T *address(T &r) { return &r; }
int call_with(int (*f)(int), int v) { return f(v); }
int main() {
  int (*p)(int) = std::addressof(twice);
  std::printf("%d %d\n", p(4), call_with(std::addressof(twice), 5));
  void *(*q)(void *) = std::addressof(proxy<int>);
  int k = 9;
  std::printf("%d\n", q(&k) == &k);
  std::printf("%s %s %s\n", kind_of(twice), kind_of_c(twice), kind_of_v(twice));
  std::printf("%d\n", address(twice)(6));
  int n = 3;
  std::printf("%s\n", kind_of(n));
  return 0;
}

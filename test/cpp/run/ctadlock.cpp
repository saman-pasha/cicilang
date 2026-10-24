#include <cstdio>
#include <mutex>
#include <shared_mutex>
#include <vector>
// class template argument deduction through a constructor whose parameter names a member typedef of the class
// template (`explicit lock_guard(mutex_type &)' over `typedef _Mutex mutex_type;'): C++17's lock idioms
template <class T> struct Box {
  typedef T value_type;
  explicit Box(const value_type &v) : v(v) {}
  value_type v;
};
int main() {
  std::mutex m;
  std::shared_mutex sm;
  {
    std::lock_guard g(m);
    std::printf("locked %d\n", (int) !m.try_lock());
  }
  {
    std::unique_lock u(m);
    std::printf("owns %d\n", (int) u.owns_lock());
    u.unlock();
    std::printf("owns %d\n", (int) u.owns_lock());
  }
  {
    std::shared_lock s(sm);
    std::printf("shared %d\n", (int) s.owns_lock());
  }
  {
    std::scoped_lock both(m, sm);
    std::printf("scoped %d\n", (int) !m.try_lock());
  }
  Box b(42);
  std::vector v{1, 2, 3};
  std::printf("%d %zu\n", b.v, v.size());
  return 0;
}

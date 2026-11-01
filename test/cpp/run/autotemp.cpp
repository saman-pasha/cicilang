// A member's `auto' result deduced where the call stands: the temporaries of its return are no temporaries of the
// caller's statement. Registered there, they were destroyed at the statement's end, never constructed (0.252).
#include <cstdio>
struct T {
  int id;
  explicit T(int i) : id(i) { std::printf("make %d\n", id); }
  T(T &&o) noexcept : id(o.id) { o.id = -1; }
  ~T() { std::printf("drop %d\n", id); }
};
int store = 0;
int &slot(const T &t) { store += t.id; return store; }
template <class X> struct M {
  X base;
  template <class F> auto get(F f) { return T(base + f()); }      // `auto'
  template <class F> auto &at(F f) { return slot(T(base * f())); } // `auto &'
};
int main() {
  M<int> m{10};
  T t = m.get([] { return 3; });
  std::printf("got %d\n", t.id);
  m.at([] { return 2; }) += 1;
  std::printf("store %d\n", store);
  return 0;
}

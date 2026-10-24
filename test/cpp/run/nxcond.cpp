// A conditional noexcept(E) (C++11, [except.spec]/2): E is evaluated for each specialization, under its bindings
#include <cstdio>
#include <functional>
#include <type_traits>
#include <utility>
template <class T> void f(T) noexcept(sizeof(T) > 4) {}
template <class T> struct W {
  W() {}
  W(const W &) {}
  W(W &&) noexcept(sizeof(T) > 1) {}
  void g() noexcept(std::is_integral_v<T>) {}
};
struct M { M() {} M(M &&) noexcept(false) {} M(const M &) {} M &operator=(M &&) noexcept(false) { return *this; } };
struct N { N() {} N(N &&) noexcept(true) {} N(const N &) {} N &operator=(N &&) noexcept { return *this; } };
constexpr bool yes() { return true; }
void h() noexcept(yes()) {}
void k() noexcept(!yes()) {}
template <class T> void fwd(T &&t) noexcept(noexcept(f(t))) {}
int main() {
  std::printf("%d %d %d\n", (int) noexcept(f(1)), (int) noexcept(f(1.0)), (int) noexcept(f('c')));
  W<int> wi;
  W<double> wd;
  std::printf("%d %d\n", (int) noexcept(wi.g()), (int) noexcept(wd.g()));
  std::printf("%d %d %d %d\n", (int) std::is_nothrow_move_constructible_v<W<char>>, (int) std::is_nothrow_move_constructible_v<W<int>>,
              (int) std::is_nothrow_move_constructible_v<M>, (int) std::is_nothrow_move_constructible_v<N>);
  std::printf("%d %d %d %d\n", (int) noexcept(h()), (int) noexcept(k()), (int) noexcept(fwd(1)), (int) noexcept(fwd(2.0)));
  std::printf("%d %d %d\n", (int) std::is_nothrow_invocable_v<void (*)()>, (int) std::is_nothrow_invocable_v<void (*)() noexcept>,
              (int) std::is_nothrow_invocable_v<decltype(h)>);
  std::printf("%d %d\n", (int) std::is_nothrow_swappable_v<M>, (int) std::is_nothrow_swappable_v<N>);
  int a = 1, b = 2;
  M m1, m2;
  std::printf("%d %d\n", (int) noexcept(std::swap(a, b)), (int) noexcept(std::swap(m1, m2)));
}

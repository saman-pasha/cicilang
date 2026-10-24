// noexcept through function templates (0.199): an instance's conditional noexcept by its callee's type, a template without noexcept,
// std::__invoke and is_nothrow_invocable over a pointer to a function with and without noexcept
#include <cstdio>
#include <type_traits>
#include <utility>
template <class F> auto inv(F &&f) noexcept(noexcept(static_cast<F &&>(f)())) -> decltype(static_cast<F &&>(f)()) { return static_cast<F &&>(f)(); }
template <class T> T &&dv();
void pl() {}
void pn() noexcept {}
int main() {
  std::printf("%d %d\n", (int) noexcept(inv(dv<void (*)()>())), (int) noexcept(inv(dv<void (*)() noexcept>())));
  std::printf("%d %d\n", (int) noexcept(std::__invoke(std::declval<void (*)()>())), (int) noexcept(std::__invoke(std::declval<void (*)() noexcept>())));
  std::printf("%d %d\n", (int) noexcept(inv(pl)), (int) noexcept(inv(pn)));
  std::printf("%d %d\n", (int) std::is_nothrow_invocable_v<void (*)()>, (int) std::is_nothrow_invocable_v<void (*)() noexcept>);
}

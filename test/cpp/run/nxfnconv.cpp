#include <cstdio>
template <class R> int g(R (*f)()) { return f(); }
template <class R> int h(R (&f)()) { return f() + 10; }
template <class R, class C> int pm(R (C::*f)(), C &c) { return (c.*f)() + 20; }
template <class R, class... A> int va(R (*f)(A...), A... a) { return f(a...); }
template <class T> struct S { static constexpr int v = 0; };
template <class R> struct S<R()> { static constexpr int v = 1; };
template <class R> struct S<R() noexcept> { static constexpr int v = 2; };
template <bool B> int nx(void (*)() noexcept(B)) { return B ? 7 : 8; }
struct Q { int f() noexcept { return 5; } };
int k() noexcept { return 3; }
int m() { return 4; }
void vn() noexcept {}
void vt() {}
int add(int x, int y) noexcept { return x + y; }
int main() {
  Q q;
  std::printf("%d %d %d %d %d\n", g(k), g(m), h(k), pm(&Q::f, q), va(add, 1, 2));
  std::printf("%d %d %d %d\n", S<int()>::v, S<int() noexcept>::v, nx(vn), nx(vt));
  return 0;
}

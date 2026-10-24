#include <coroutine>
#include <cstdio>
// a coroutine_handle compared with nullptr and with another handle (C++20): libc++'s free operator==, a header's
// function emitted where it is called and declared under the name it is emitted under (0.202: no_operator(==))
struct P {};
int main() {
  std::coroutine_handle<P> h;
  std::coroutine_handle<> g;
  std::printf("%d\n", g == nullptr);
  std::printf("%d\n", h == g);
  std::printf("%d\n", h == nullptr);
  return 0;
}

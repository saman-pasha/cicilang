#include <cstdio>
#include <cstddef>
struct [[gnu::packed]] S { char c; int i; };
struct T { char c; [[gnu::aligned(16)]] int i; };
struct [[__gnu__::__aligned__(32)]] U { int v; };
using A8 [[gnu::aligned(8)]] = int;
struct V { char c; A8 a; };
[[gnu::aligned(64)]] int g = 1;
int main() {
  std::printf("%d %d %d %d\n", (int) sizeof(S), (int) offsetof(S, i), (int) sizeof(T), (int) offsetof(T, i));
  std::printf("%d %d %d %d\n", (int) sizeof(U), (int) alignof(U), (int) alignof(A8), (int) offsetof(V, a));
  std::printf("%d %d %d\n", (int) (((std::size_t) &g) % 64), __has_cpp_attribute(gnu::packed), __has_cpp_attribute(gnu::aligned));
  return 0;
}

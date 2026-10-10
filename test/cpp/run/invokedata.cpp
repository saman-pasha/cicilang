// A pointer to a DATA member as the callee of std::invoke, invoke_result and is_invocable: `o.*pm' for an object (its value category
// the result's), `p->*pm' for a pointer to it. libc++ 21 writes all three on clang's `__builtin_invoke'; libc++ 18 on overloads of
// `__invoke' that read `std::forward<_A0>(__a0).*__f'.
#include <cstdio>
#include <functional>
#include <type_traits>
struct Pt { int x; int y; };
int main() {
  using R1 = std::invoke_result_t<int Pt::*, Pt &>;
  using R2 = std::invoke_result_t<int Pt::*, const Pt &>;
  using R3 = std::invoke_result_t<int Pt::*, Pt *>;
  using R4 = std::invoke_result_t<int Pt::*, Pt &&>;
  std::printf("%d %d %d %d\n", (int) std::is_same_v<R1, int &>, (int) std::is_same_v<R2, const int &>, (int) std::is_same_v<R3, int &>,
              (int) std::is_same_v<R4, int &&>);
  std::printf("%d %d %d\n", (int) std::is_invocable_v<int Pt::*, Pt &>, (int) std::is_invocable_v<int Pt::*, Pt *>,
              (int) std::is_invocable_v<int Pt::*, int>);
  Pt p{3, 4};
  std::invoke(&Pt::x, p) = 10;
  const Pt *cp = &p;
  std::printf("%d %d %d\n", std::invoke(&Pt::x, p), std::invoke(&Pt::y, cp), std::invoke(&Pt::y, Pt{7, 8}));
  return 0;
}

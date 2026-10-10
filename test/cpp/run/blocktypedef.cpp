// A typedef in a block is a name of that block only ([basic.scope.block]); the unit's one table of
// typedefs held every block's, so a file-scope alias declared after a function that used its name in
// a block resolved to the block's type in the functions below (0.127)
#include <cstdio>
#include <type_traits>

void f() { using Size = double; Size d = 1.5; std::printf("f %.1f %zu\n", d, sizeof(Size)); }
using Size = int;
void g() { Size s = 3; std::printf("g %d %zu\n", s, sizeof(Size)); }
template <class T> int count(T) { using Elem = T *; return (int) sizeof(Elem); }
struct Elem { char c[3]; };
int h() { Elem e{}; return (int) sizeof(e); }
template <class _Tp> void k(_Tp x) { using _Up = _Tp[2]; _Up a = {x, x}; std::printf("k %zu\n", sizeof(a)); }
template <class _Up> void m(_Up u) { std::printf("m %d %zu\n", (int) std::is_same_v<_Up, short>, sizeof(u)); }
int main() {
  f(); g();
  std::printf("%d %d\n", count('a'), h());
  k(1L);
  m((short) 1);
  return 0;
}

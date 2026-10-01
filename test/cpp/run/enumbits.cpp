// A type's sign and size, as libc++ 18's format-spec parser asks them: an enum whose underlying type is a typedef is
// sized by it ([dcl.enum]/5), an enumeration is a scalar type whose braced default member initializer is its one
// item ([basic.types.general]/9), and a bitfield is read with its type's sign -- a `bool' or a scoped enum over
// `uint8_t' unsigned, a `char16_t' unsigned ([basic.fundamental]).
#include <cstdio>
#include <cstdint>
enum class Al : uint8_t { a, b, c, d, e, f, g, h };
enum class Sg : int8_t { m = -2, z = 0, p = 1 };
struct Plain { Al al_; int x; };
struct CP { char d[4] = {' '}; };
template <class C> struct Par {
  Al al_ : 3 {Al::h};
  Sg sg_ : 2 {Sg::m};
  bool f_ : 1 {false};
  bool t_ : 1 {true};
  Al whole_{Al::c};
  uint8_t r0_ : 2 {0};
  uint8_t r1_ : 6 {45};
  int32_t w_{0};
  int32_t p_{-1};
  CP fill_{};
};
int main() {
  Plain q;
  q.al_ = Al::e;
  q.x = 4;
  std::printf("%d %d %d\n", (int) q.al_, q.x, (int) sizeof(Plain));
  Par<char> p;
  std::printf("%d %d %d %d %d %d %d %d %d\n", (int) p.al_, (int) p.sg_, (int) p.f_, (int) p.t_, (int) p.whole_,
              (int) p.r1_, p.w_, p.p_, (int) p.fill_.d[0]);
  p.t_ = false;
  p.f_ = true;
  p.al_ = Al::g;
  std::printf("%d %d %d %d\n", (int) p.f_, (int) p.t_, (int) p.al_, (int) sizeof(Par<char>));
  char16_t u = 0xFFFE;
  char32_t w = 0x10FFFF;
  int iu = u;
  long lw = w;
  std::printf("%d %ld %d\n", iu, lw, u > 0 ? 1 : 0);
  return 0;
}

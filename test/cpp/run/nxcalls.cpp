#include <cstdio>
#include <string>
struct TH { TH(int) {} };
struct NT { NT(int) noexcept {} };
struct O { void m(TH) noexcept {} void n(NT) noexcept {} static void s(TH) noexcept {} };
void ov(TH) noexcept {}
void ov(TH, int) noexcept {}
void ow(NT) noexcept {}
void ow(NT, int) noexcept {}
template <class T> void dt(T, TH) noexcept {}
template <class T> void du(T, NT) noexcept {}
struct C { operator TH() const { return TH(1); } };
struct D { operator NT() const noexcept { return NT(1); } };
void takes(TH) noexcept {}
void takesn(NT) noexcept {}
int main() {
  O o;
  std::printf("%d %d %d %d %d\n", noexcept(o.m(1)), noexcept(ov(1)), noexcept(dt(1, 2)), noexcept(std::string("x")), noexcept(takes(C())));
  std::printf("%d %d %d %d\n", noexcept(o.n(1)), noexcept(ow(1)), noexcept(du(1, 2)), noexcept(takesn(D())));
  std::printf("%d %d\n", noexcept(O::s(1)), noexcept(o.s(1)));
  return 0;
}

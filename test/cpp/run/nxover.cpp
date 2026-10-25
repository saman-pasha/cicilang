#include <cstdio>
struct TH { TH(int) {} };
void ov3(TH) noexcept {}
void ov3(const char *) noexcept {}
void tf() {}
void nf() noexcept {}
template <bool B> int callp(void (*f)() noexcept(B)) { return noexcept(f()); }
struct M { int g() { return 1; } int h() noexcept { return 2; } };
template <bool B> int callm(int (M::*pm)() noexcept(B)) { M m; return noexcept((m.*pm)()); }
int main() {
  std::printf("%d\n", noexcept(ov3(1)));
  std::printf("%d %d\n", callp<false>(tf), callp<true>(nf));
  std::printf("%d %d\n", callm<false>(&M::g), callm<true>(&M::h));
  return 0;
}

// the noexcept operator over the constructors a call runs: by-value and reference parameters, temporaries, prvalues
#include <cstdio>
#include <string>
#include <type_traits>
struct TH { TH(int) {} };
struct NX { NX(int) noexcept {} };
struct MV { MV() noexcept {} MV(const MV &) {} MV(MV &&) noexcept(false) {} };
struct AG { int a; int b; };
void g(TH) noexcept;
void gn(NX) noexcept;
void gr(const TH &) noexcept;
void gs(std::string) noexcept;
void gm(MV) noexcept;
void ga(AG) noexcept;
template <class T> void h(T) noexcept;
template <class T> void hr(const T &) noexcept;
int main() {
  TH t(1);
  MV m;
  std::printf("%d %d %d %d %d %d\n", (int) noexcept(g(1)), (int) noexcept(gn(1)), (int) noexcept(gr(1)), (int) noexcept(gr(t)), (int) noexcept(g(t)), (int) noexcept(gs("x")));
  std::printf("%d %d %d %d %d %d\n", (int) noexcept(h<TH>(1)), (int) noexcept(h(TH(1))), (int) noexcept(h<NX>(1)), (int) noexcept(hr<TH>(1)), (int) noexcept(hr(t)), (int) noexcept(TH(2)));
  std::printf("%d %d %d %d %d %d\n", (int) noexcept(NX(2)), (int) noexcept(gm(MV())), (int) noexcept(gm(m)), (int) noexcept(gm(static_cast<MV &&>(m))), (int) noexcept(ga(AG{1, 2})), (int) noexcept(AG{1, 2}));
  std::printf("%d %d\n", (int) std::is_nothrow_convertible_v<int, TH>, (int) std::is_nothrow_convertible_v<int, NX>);
}

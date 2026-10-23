// C++20's non-type template parameters of class and floating type (P1907), and C++17's auto ones
#include <cstdio>
#include <cstddef>
struct Pt { int x, y; };
template <Pt P> int sum() { return P.x + P.y; }
template <double D> double twice() { return D * 2; }
template <auto V> constexpr auto val = V;
template <std::size_t N> struct Str { char s[N]; constexpr Str(const char (&a)[N]) { for (std::size_t i = 0; i < N; i++) s[i] = a[i]; } };
template <Str S> const char *name() { return S.s; }
template <auto... Vs> int count() { return sizeof...(Vs); }
int main() {
    std::printf("%d %d %g %d %c\n", sum<Pt{1, 2}>(), sum<Pt{3, 4}>(), twice<1.5>(), val<3>, val<'z'>);
    std::printf("%s %s %d\n", name<"hello">(), name<"x">(), count<1, 'a', true>());
}

// Value template arguments spelled as clang spells them in __PRETTY_FUNCTION__ (0.199): suffixes, casts, character literals and their
// escapes, a placeholder's by its own type, a pack; S<5> and S<5u> two instances of template <auto N>, U<5> and U<5u> one
#include <cstdio>
#include <type_traits>
#include <typeinfo>
template <auto N> void f() { std::puts(__PRETTY_FUNCTION__); }
template <long long N> void g() { std::puts(__PRETTY_FUNCTION__); }
template <unsigned long long N> void h() { std::puts(__PRETTY_FUNCTION__); }
template <auto N> struct S { void m() { std::puts(__PRETTY_FUNCTION__); } };
template <long long N> struct T { void m() { std::puts(__PRETTY_FUNCTION__); } };
template <char C> struct TC { void m() { std::puts(__PRETTY_FUNCTION__); } };
template <short C> struct TS { void m() { std::puts(__PRETTY_FUNCTION__); } };
template <unsigned char C> struct TU { void m() { std::puts(__PRETTY_FUNCTION__); } };
template <unsigned N> struct U { static constexpr unsigned v = N; };
template <class T, T V> void dep() { std::puts(__PRETTY_FUNCTION__); }
template <char C> void kc() { std::puts(__PRETTY_FUNCTION__); }
template <signed char C> void sc() { std::puts(__PRETTY_FUNCTION__); }
template <unsigned short C> void us() { std::puts(__PRETTY_FUNCTION__); }
template <wchar_t C> void wc() { std::puts(__PRETTY_FUNCTION__); }
template <char16_t C> void c16() { std::puts(__PRETTY_FUNCTION__); }
template <char32_t C> void c32() { std::puts(__PRETTY_FUNCTION__); }
template <unsigned... Ns> void up() { std::puts(__PRETTY_FUNCTION__); }
template <auto... Ns> void ap() { std::puts(__PRETTY_FUNCTION__); }
template <auto N> constexpr bool is_short() { return std::is_same_v<decltype(N), short>; }
template <auto N> constexpr bool is_uns() { return std::is_same_v<decltype(N), unsigned>; }
int main() {
  f<5>(); f<5u>(); f<5l>(); f<5ul>(); f<5ll>(); f<5ull>(); f<'a'>(); f<true>(); f<(short)9>(); f<(unsigned char)66>();
  f<(signed char)-3>(); f<L'w'>(); f<u'x'>(); f<U'y'>();
  g<5>(); g<-3>(); h<5>();
  S<5u>{}.m(); S<'b'>{}.m(); S<(short)4>{}.m(); S<true>{}.m(); S<5ll>{}.m(); T<7>{}.m();
  TC<'x'>{}.m(); TC<10>{}.m(); TS<9>{}.m(); TU<66>{}.m();
  dep<unsigned, 5>(); dep<char, 'z'>(); dep<long, -2>();
  kc<10>(); kc<0>(); kc<39>(); kc<92>(); kc<'"'>(); kc<(char)200>(); kc<127>(); kc<9>();
  sc<65>(); us<7>(); wc<L'q'>(); c16<u'r'>(); c32<U's'>();
  up<1, 2>(); ap<1, 2u, 'c'>();
  std::printf("%d %d %d %d\n", (int) std::is_same_v<S<5>, S<5u>>, (int) std::is_same_v<U<5>, U<5u>>, (int) is_short<(short)1>(), (int) is_uns<3u>());
  std::printf("%s %s %s\n", typeid(S<5u>).name(), typeid(S<'a'>).name(), typeid(S<(short)3>).name());
  std::printf("%u\n", U<4000000000u>::v);
}

// A template-id in a specialization's pattern names the template WITH ITS DEFAULTS: `str<C>' is
// `str<C, traits<C>, int>', and `std::basic_string<C>' is the string with its traits and allocator.
#include <cstdio>
#include <string>
template <class C> struct traits {};
template <class C, class T = traits<C>, class A = int> struct str { C c; };
template <class X> inline constexpr bool ins = false;
template <class C> inline constexpr bool ins<str<C>> = true;
template <class X> struct cont { static constexpr int k = 0; };
template <class C> struct cont<str<C>> { static constexpr int k = 1; };
template <class X> inline constexpr bool isstr = false;
template <class C> inline constexpr bool isstr<std::basic_string<C>> = true;
int main() {
  std::printf("%d %d %d %d\n", ins<str<char>>, ins<str<char, traits<char>, long>>, cont<str<int>>::k, cont<str<int, int>>::k);
  std::printf("%d %d\n", isstr<std::string>, isstr<str<char>>);
  return 0;
}

// a template argument that names no template parameter is matched exactly (0.221; [temp.deduct.type]/8): `put(O<char, T> &, ...)'
// is no candidate for an O<wchar_t, wchar_t>. The match took any type there and made B<char, wchar_t>, whose static assertion
// fails -- as libc++ 18's deleted `operator<<(basic_ostream<char, _Traits> &, const wchar_t *)' made basic_ios<char,
// char_traits<wchar_t>> from every wide stream's inserter
#include <cstdio>
template <class C, class T> struct B { static_assert(sizeof(C) == sizeof(T), "B needs one character type"); virtual ~B() {} };
template <class C, class T> struct O : B<C, T> { };
template <class T> int put(O<char, T> &, const wchar_t *) { return 1; }
template <class C, class T> int put(O<C, T> &, const C *) { return 2; }
int main() {
  O<wchar_t, wchar_t> o;
  std::printf("%d\n", put(o, L"x"));
}

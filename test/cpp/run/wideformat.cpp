// overloads told apart by a constructor template's constraint: a wide literal takes the wchar_t overload, as
// std::format(L"...") must ([over.match.copy]; libc++'s basic_format_string)
#include <concepts>
#include <cstdio>
#include <string_view>
#include <type_traits>
template <class C, class... A> struct FS {
  std::basic_string_view<C> s;
  template <class T> requires std::convertible_to<const T &, std::basic_string_view<C>> FS(const T &t) : s(t) {}
};
template <class... A> int f(FS<char, std::type_identity_t<A>...> s, A &&...) { return 100 + (int) s.s.size(); }
template <class... A> int f(FS<wchar_t, std::type_identity_t<A>...> s, A &&...) { return 200 + (int) s.s.size(); }
int main() {
  std::printf("%d %d\n", (int) std::is_convertible_v<const wchar_t *, std::string_view>, (int) std::is_convertible_v<const char *, std::string_view>);
  std::printf("%d %d\n", f("ab", 1), f(L"xyz", 2));
  return 0;
}

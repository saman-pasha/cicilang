// a constant wide string_view built at compile time, as libc++'s __bool_strings<wchar_t> holds them
#include <cstdio>
#include <string_view>
struct Words {
  static constexpr std::wstring_view yes{L"true"};
  static constexpr std::wstring_view no{L"false"};
};
constexpr std::u32string_view g{U"été"};
int main() {
  std::printf("%zu %zu %zu\n", Words::yes.size(), Words::no.size(), g.size());
  for (wchar_t c : Words::no) std::printf("%c", (char) c);
  std::printf(" %d %d\n", (int) g[0], (int) Words::yes[3]);
  return 0;
}

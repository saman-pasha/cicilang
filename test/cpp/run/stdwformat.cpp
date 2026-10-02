// std::format over wide strings (C++20)
#include <cstdio>
#include <format>
#include <string>
int main() {
  std::wstring w = std::format(L"{} {:x}", 42, 255);
  for (wchar_t c : w) std::printf("%c", (char) c);
  std::printf(" %zu\n", w.size());
  return 0;
}

// C++17's u8 literals ([lex.ccon], [lex.string]): u8'c' a char, u8"..." `const char[N]', its bytes UTF-8; a
// multi-character constant an int; adjacent wide literals one (0.196)
#include <cstdio>
#include <string>
#include <type_traits>
int f(char) { return 1; }
int f(int) { return 3; }
int main() {
    auto c = u8'a';
    std::printf("%d %d %d %d\n", (int) std::is_same_v<decltype(c), char>, f(u8'a'), f('ab'), (int) std::is_same_v<decltype(u8"x"), const char (&)[2]>);
    std::string s = u8"hé";
    std::printf("%zu %d %d\n", s.size(), (int) (unsigned char) s[1], (int) (unsigned char) s[2]);
    const wchar_t *w = L"ab" "cd"; const char16_t *u = "x" u"yz";
    std::printf("%d %d %zu %zu\n", (int) w[3], (int) u[2], sizeof(L"ab" "cd"), sizeof(U"é" "😀"));
    return 0;
}

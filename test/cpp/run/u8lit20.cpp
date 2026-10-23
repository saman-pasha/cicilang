// C++20's u8 literals ([lex.ccon]/3, [lex.string]/6): u8'c' a char8_t, u8"..." `const char8_t[N]', std::u8string over
// them; overloads and deduction by them; a prefixed character literal one character, a multi-character constant an int;
// adjacent string literals one, of the prefix (0.196)
#include <cstdio>
#include <string>
#include <type_traits>
int f(char) { return 1; }
int f(char8_t) { return 2; }
int f(int) { return 3; }
int g(const char *) { return 1; }
int g(const char8_t *) { return 2; }
template <class T> int kind(T) { return std::is_same_v<T, char8_t> ? 8 : std::is_same_v<T, char> ? 1 : 0; }
template <class T, std::size_t N> std::size_t len(const T (&)[N]) { return N; }
int main() {
    auto c = u8'a';
    std::printf("%d %zu %d %d %d %d\n", (int) c, sizeof c, f(u8'a'), f('a'), f('ab'), kind(u8'z'));
    std::printf("%d %d %d %zu\n", (int) std::is_same_v<decltype(u8"x"), const char8_t (&)[2]>, g(u8"x"), g("x"), len(u8"hé"));
    std::u8string s = u8"hé" u8"llo";
    std::printf("%zu %d %d %d\n", s.size(), (int) s[1], (int) s[2], (int) (s == u8"héllo"));
    const char8_t *p = u8"x" "y";
    std::printf("%d %d %d\n", (int) p[0], (int) p[1], (int) std::is_same_v<decltype('ab'), int>);
    std::printf("%d %d %u\n", (int) L'é', (int) u'€', (unsigned) U'😀');
    return 0;
}

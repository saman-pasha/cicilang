// A CALL OVER `const std::string &' WITH <string> UNREAD (0.181): <iosfwd> declares the class template std::basic_string
// and the alias std::pmr::basic_string, which names `std::basic_string<_CharT, _Traits, polymorphic_allocator<_CharT>>';
// flattened to one bare name the alias won, resolved itself without end, and the build ran to the memory cap
#include <cstdio>
#include <iosfwd>
#include <stdexcept>
int g(const std::string &);
int g(const char *s) { return s[0]; }
struct R { explicit R(const std::string &); explicit R(const char *p) : k(p[1]) {} int k; };
int main() {
    std::printf("%d %d\n", g("abc"), R("xyz").k);
    try { throw std::logic_error("lg"); } catch (const std::exception &e) { std::printf("what: %s\n", e.what()); }
    return 0;
}

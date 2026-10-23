// A plain character literal's value past 127 is a char's ([lex.ccon]/2): signed on x86-64 Linux; in an expression, a
// template argument, a case label and #if alike (0.196)
#include <cstdio>
template <char C> int val() { return C; }
int main() {
    char c = '\xff';
    static_assert('\xff' == -1 && '\x80' < 0, "signed");
    std::printf("%d %d %d %d %d\n", '\xE9', (int) '\377', c == '\xff', val<'\xE9'>(), (int) sizeof('\xE9'));
    switch (c) { case '\xff': std::puts("ff"); break; default: std::puts("other"); }
#if '\xff' < 0
    std::puts("pp signed");
#else
    std::puts("pp unsigned");
#endif
}

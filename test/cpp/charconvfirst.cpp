// <charconv> alone, built first over a summary directory of its own, so that a later build serves the header from its summary
// while the rest of its headers are cold (test/cpp.sh, 0.218)
#include <charconv>
int main() { int v = 0; const char *s = "7"; std::from_chars(s, s + 1, v); return v - 7; }

// refused: a private operator used as an operator ([class.access]/4, [over.match.oper])
#include <cstdio>
class Money { int c; bool operator<(const Money &o) const { return c < o.c; } public: explicit Money(int x) : c(x) {} };
int main() { Money a(1), b(2); std::printf("%d\n", (int) (a < b)); return 0; }

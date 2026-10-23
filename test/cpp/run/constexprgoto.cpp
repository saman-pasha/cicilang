#include <cstdio>
constexpr int gotos(int n) { int r = 0; loop: if (n > 0) { r += n; --n; goto loop; } return r; }
int main() { int g = gotos(4); std::printf("%d\n", g); }

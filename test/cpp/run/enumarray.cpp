// a global std::array of the program's own enum, braced with elision: the enum mangled as a global name, the global's constant elided (0.110)
#include <cstdio>
#include <array>
enum class K : unsigned char { a, b, c };
static constexpr std::array<K, 2> ks{K::a, K::c};
int main() { std::printf("%d %d\n", (int) ks[1], (int) ks.size()); return 0; }

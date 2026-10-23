#include <cstdio>
template <class... Ts> auto first(Ts... ts) { return ts...[0]; }
void gone() = delete("use other");
int main() { std::printf("%d\n", first(8, 9)); }

#include <cstdio>
#include <cstddef>
#include <type_traits>
int main() { auto z = 5uz; auto zs = 6z; std::printf("%d %d %zu\n", (int) std::is_same_v<decltype(z), std::size_t>, (int) std::is_same_v<decltype(zs), std::make_signed_t<std::size_t>>, z + zs); }

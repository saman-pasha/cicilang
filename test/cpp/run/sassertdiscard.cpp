#include <cstdio>
#include <type_traits>
template <class T> int kind() { if constexpr (std::is_integral_v<T>) return 1; else if constexpr (std::is_floating_point_v<T>) return 2; else static_assert(false, "no"); }
int main() { std::printf("%d %d\n", kind<int>(), kind<double>()); }

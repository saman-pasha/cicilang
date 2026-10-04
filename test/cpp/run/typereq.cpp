// A type requirement names a member that nothing declared before it (C++20): `typename T::key_type;' read as a type
// by its `typename', as <print>'s `format_kind' writes it
#include <cstdio>
template <class T> int kind() {
  if constexpr (sizeof(T) == 0)
    return 0;
  else if constexpr (requires { typename T::key_type; }) {
    return 1;
  } else
    return 2;
}
struct M { using key_type = int; };
int main() { std::printf("%d %d\n", kind<M>(), kind<int>()); return 0; }

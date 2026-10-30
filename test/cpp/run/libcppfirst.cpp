// 0.239: libc++'s __config reads the program's _LIBCPP_* names once, at the first #include of the library: a name the
// program defines after it reaches no header, as in clang++ (libc++ 18 makes the C++20 removed features' names from it)
#include <cstdio>
#define _LIBCPP_ENABLE_CXX20_REMOVED_FEATURES
#include <memory>
int main() {
#ifdef _LIBCPP_ENABLE_CXX20_REMOVED_ALLOCATOR_MEMBERS
  std::printf("the late name was read\n");
#else
  std::printf("the late name was not read\n");
#endif
  return 0;
}

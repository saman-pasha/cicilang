// A prvalue of non-class type has no top-level cv-qualifier ([expr.type]/2): a compound requirement over
// `__j + __n' with `const T *const __j' asks for a `const T *', and a pointer is a contiguous iterator.
#include <cstdio>
#include <iterator>
#include <concepts>
template <class I> concept addable = requires(const I j, int n) { { j + n } -> std::same_as<I>; };
int main() {
  std::printf("%d %d %d %d\n", (int) addable<const char *>, (int) addable<int *>, (int) std::random_access_iterator<const char *>,
              (int) std::contiguous_iterator<const char *>);
  return 0;
}

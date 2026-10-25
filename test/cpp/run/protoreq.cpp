#include <cstdio>
template <class T> int f(T) requires (sizeof(T) > 4);
template <class T> int f(T) requires (sizeof(T) <= 4);
template <class T> struct K { int g() requires (sizeof(T) > 1); int g() requires (sizeof(T) == 1); };
int main() {
  K<char> kc; K<long> kl;
  std::printf("%d %d %d %d\n", f(1), f(1.0), kc.g(), kl.g());
#if __has_cpp_attribute(clang::fallthrough) && __has_cpp_attribute(gnu::unused)
  std::printf("scoped %d %d\n", (int) __has_cpp_attribute(clang::fallthrough), (int) __has_cpp_attribute(gnu::always_inline));
#else
  std::printf("no scoped\n");
#endif
  return 0;
}
template <class T> int f(T) requires (sizeof(T) > 4) { return 8; }
template <class T> int f(T) requires (sizeof(T) <= 4) { return 4; }
template <class T> int K<T>::g() requires (sizeof(T) > 1) { return 20; }
template <class T> int K<T>::g() requires (sizeof(T) == 1) { return 10; }

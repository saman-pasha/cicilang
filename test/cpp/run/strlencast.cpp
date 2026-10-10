// libc++ 21's __constexpr_strlen: `if (__libcpp_is_constant_evaluated()) {...}' then `return __builtin_strlen(reinterpret_cast<const char *>(__str))'
// (the evaluator takes the second branch, its is_constant_evaluated is false): a static constexpr member built by the constructor folds
#include <cstdio>
#include <cstring>
template <class T> constexpr unsigned long clen(const T *s) {
  if (__builtin_is_constant_evaluated()) {
    unsigned long i = 0;
    for (; s[i] != '\0'; ++i)
      ;
    return i;
  }
  return __builtin_strlen(reinterpret_cast<const char *>(s));
}
struct V {
  unsigned long n;
  constexpr V(const char *s) : n(clen(s)) {}
};
template <class C> struct W {
  static constexpr V yes{"true"};
  static constexpr V no{"false"};
};
int main() {
  std::printf("%lu %lu\n", W<char>::yes.n, W<char>::no.n);
  return 0;
}

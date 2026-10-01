// A qualified path of two or more segments is walked, each segment named inside the one before (0.112): resolved in a
// class whose own `type' is a class -- libc++'s __invokable_r -- `Cache<T>::type::template Ap<T>' is Inner<T>'s alias,
// never a member of the asking class's `type'
#include <cstdio>
template <class T> struct Inner { template <class U> using Ap = U *; static const int tag = 7; };
template <class T> struct Cache { using type = Inner<T>; };
struct Other { static const int tag = 1; };
template <class T> struct Ctx {
  using type = Other;
  using P = typename Cache<T>::type::template Ap<T>;
  static const int t = Cache<T>::type::tag;
  static int f() { P p = nullptr; return p == nullptr ? t : 0; }
};
int main() { std::printf("%d %d\n", Ctx<int>::f(), Ctx<int>::type::tag); return 0; }

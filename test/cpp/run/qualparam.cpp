// A qualified name that names no type declares no parameter (0.186): `R::tag', an enumerator, and `Q::less', a static
// data member, beside the class templates `tag' and `less', are expressions, so `O::low(R::tag)' defines the static and
// initializes it, and `O b(R::tag);' and `int y(Q::less);' in a block declare objects. Read as a parameter's type,
// `R::tag' made the definition a declaration of a member function, which no item kept, and the two block declarations
// functions.
#include <cstdio>

template <class T> struct tag { T v; };
template <class T> struct less { bool operator()(const T &a, const T &b) const { return a < b; } };

enum class R : signed char { tag = -1, other = 1 };

struct O {
  signed char v;
  constexpr explicit O(R r) : v((signed char) r) {}
  static const O low;
  static const O high;
};

inline constexpr O O::low(R::tag);
inline constexpr O O::high(R::other);

struct Q { static const int less = 3; };

int main() {
  O b(R::tag);
  int y(Q::less);
  less<int> lt;
  tag<int> t{y};
  std::printf("%d %d %d %d %d %d\n", O::low.v, O::high.v, b.v, y, (int) lt(1, 2), t.v);
  return 0;
}

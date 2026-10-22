// A template template parameter's own parameter list with a comparison in parentheses (0.184):
// `template <template <class T, bool = (sizeof(T) < 4)> class TT>'. The reader skips that list to its `>' by
// counting angle brackets, and the `<' of the comparison was counted: the list ran on past its close and the
// head was a syntax error (a `>' in the parentheses closed it too soon). A parenthesized group is skipped whole
// now, as the scan ahead of a class body skips one since 0.183. Here the list's defaults agree with the templates'
// own; since 0.185 the list is read and its defaults apply where they differ (ttpown.cpp).
#include <cstdio>

template <class T, bool B = (sizeof(T) < 4)> struct Small { static const int v = B ? 1 : 2; };
template <class T, bool B = (sizeof(T) > 2)> struct Wide { static const int v = B ? 3 : 4; };

template <template <class T, bool = (sizeof(T) < 4)> class TT, class U> struct Use { static const int v = TT<U>::v; };

template <template <class, bool> class TT> struct Two { static const int v = TT<char, false>::v + TT<long, true>::v; };

struct M {
  template <template <class T, bool = (sizeof(T) > 2)> class TT, class U> static int get() { return TT<U>::v * 10; }
};

int main() {
  std::printf("%d %d %d %d %d\n", Use<Small, char>::v, Use<Small, long>::v, Two<Small>::v, M::get<Wide, char>(),
              M::get<Wide, long>());
  return 0;
}

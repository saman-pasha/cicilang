// A template template parameter's own default arguments (0.185; [temp.param]/14): in the scope of the parameter,
// `TT<U>' takes the PARAMETER's defaults, not the bound template's own. The reader skipped the parameter's own list,
// and `TT<U>' took the bound template's defaults: `Use<Small, char>::v' was 1, where clang++ gives 2. Here the list
// is read, its defaults bound beside the parameter and given where `TT<U>' leaves them out: in a class template's
// head, beside a value parameter, an outer parameter and a pack, in a function template's, a member template's and a
// class template's member template's head. A list with no default leaves the bound template's own.
#include <cstdio>

template <class T, bool B = (sizeof(T) < 4)> struct Small { static const int v = B ? 1 : 2; };
template <class T, int N = 3> struct Holder { static const int n = N; };
template <class A, class B = A> struct Pair { static int size() { return sizeof(A) + sizeof(B); } };

template <template <class T, bool = (sizeof(T) > 2)> class TT, class U> struct Use { static const int v = TT<U>::v; };
template <template <class T, int = 7> class TT> struct Seven { static int get() { return TT<char>::n; } };
template <class X, template <class T, class = X> class TT> struct Outer { typedef TT<int> type; };
template <template <class T, int = 5> class TT> int five() { return TT<char>::n; }
struct M {
  template <template <class T, int = 9> class TT> static int nine() { return TT<long>::n; }
};

// a parameter pack beside it, and an argument given where the list has a default
template <template <class, int = 11> class TT, class... Ts> struct Many {
  static int get() { return TT<char>::n + TT<char, 1>::n + (int) sizeof...(Ts); }
};
// a member template of a class template: the list's default names the class's parameter
template <int K> struct Host {
  template <template <class, int = K * 2> class TT> static int get() { return TT<int>::n; }
};
// lists with no default: every argument given, and the bound template's own default
template <template <class, int> class TT> struct Plain { static int get() { return TT<int, 4>::n; } };
template <template <class...> class TT> struct Variadic { static int get() { return TT<long>::size(); } };

int main() {
  std::printf("%d %d %d %d\n", Use<Small, char>::v, Use<Small, long>::v, Small<char>::v, Small<long>::v);
  std::printf("%d %d %d %d %d\n", Seven<Holder>::get(), Holder<char>::n, Outer<double, Pair>::type::size(),
              five<Holder>(), M::nine<Holder>());
  std::printf("%d %d %d %d\n", Many<Holder, int, long>::get(), Host<6>::get<Holder>(), Plain<Holder>::get(),
              Variadic<Pair>::get());
  return 0;
}

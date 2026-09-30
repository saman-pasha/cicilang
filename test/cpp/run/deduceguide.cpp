#include <utility>
#include <cstdio>
template <class A, class B> struct same { static constexpr int v = 0; };
template <class A> struct same<A, A> { static constexpr int v = 1; };
// a deduction guide written by the program
template <class T> struct Box { T v; Box(T x, int) : v(x) {} };
template <class T> Box(T, int) -> Box<T>;
// the pointee keeps its qualifiers
template <class T> T *id(T *p) { return p; }
template <class T> const T *cid(const T *p) { return p; }
// a parameter whose template parameters are all non-deduced
template <class T> struct ident { using type = T; };
template <class T> using ident_t = typename ident<T>::type;
template <class... Ts> struct Fmt { int brace; Fmt(const char *x) : brace(x[0] == '{') {} };
template <class... Ts> int count(Fmt<ident_t<Ts>...> f, Ts... xs) { return (int) sizeof...(Ts) + f.brace; }
int main() {
  Box b(2.5, 0);
  auto p = std::pair{1, 'c'};
  const int k = 4;
  printf("%d %d %d\n", same<decltype(b), Box<double> >::v, same<decltype(p), std::pair<int, char> >::v, (int) b.v);
  printf("%d %d\n", same<decltype(id(&k)), const int *>::v, same<decltype(cid(&k)), const int *>::v);
  printf("%d\n", count("{}", 1, 2.0, 'x'));
  return 0;
}

// A PLAIN struct handed to a scalar parameter converts to nothing, so a detection that asks it is false (0.127): `callable<Eq &, P &,
// char &>' held, where Eq's operator() takes two chars and P is a struct of one int.
#include <cstdio>
#include <utility>
struct Eq { bool operator()(char a, char b) const { return a == b; } };
struct P { int v; };
struct Q { Q(int) {} ~Q() {} };
template <class F, class... A> concept callable = requires(F &&f, A &&...a) { std::forward<F>(f)(std::forward<A>(a)...); };
int plainfn(char, char) { return 0; }
int main() {
  std::printf("%d %d %d\n", (int)callable<Eq &, P &, char &>, (int)callable<Eq &, char &, char &>, (int)callable<Eq &, Q &, char &>);
  std::printf("%d %d\n", (int)callable<decltype(plainfn) &, P &, char &>, (int)callable<decltype(plainfn) &, char &, char &>);
  return 0;
}

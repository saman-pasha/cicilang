// WHAT 1.6.56'S REFERENCE RULES AND AMBIGUITIES KEEP (1.6.56): a const reference to a class binds a converted temporary; a closure's,
// a class's operator(), a template's and a defaulted overload's arguments that fit; a template beside a plain overload; a value and a
// const reference of one type beside an exact third; an overload of more parameters and no default beside an exact one; and a deleted destructor's class named in a decltype, never made
#include <cstdio>
struct S { int k; S(int j) : k(j) {} };
int cref(const S &s) { return s.k; }
struct F { int operator()(int &x) const { return x += 2; } };
template <class T> int tf(T &x, int &y) { return 1; }
int tf(long x, long y) { return 2; }
int df(int x, int y = 0) { return x + y; }
int df(double &x) { return 20; }
int tw(long x, int y) { return 1; }
int tw(const long &x, int y) { return 2; }
int tw(double x, int y) { return 3; }
int t3(long x) { return 1; }
int t3(const long &x) { return 2; }
int t3(int x) { return 3; }
struct X { int k; ~X() = delete; };
X mk();
template <class T> int deref(T &x) { return x; }
int ex(int x, int y) { return 1; }
int ex(int &x) { return 2; }
int main() {
  int i = 7;
  auto l = [](int &x) { return x *= 2; };
  auto two = [](int &x, int y) { return x = y; };
  F fo;
  long a = 0;
  double dd = 1;
  using T = decltype(mk());
  std::printf("%d %d %d %d %d\n", cref(i), cref(3), l(i), two(i, 3), fo(i));
  std::printf("%d %d %d %d %d %d %d\n", tf(a, a), df(i), df(dd), df(i, 4), tw(2.5, 1), t3(i), deref(i));
  std::printf("%d %d\n", (int)sizeof(T), ex(i));
  return 0;
}

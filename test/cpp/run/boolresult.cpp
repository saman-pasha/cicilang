// A comparison, `!', `&&' and `||' are a bool in C++, and a conditional over two arms of one
// arithmetic type has that type ([expr.rel]/1, [expr.eq]/1, [expr.log.and]/1, [expr.unary.op]/9,
// [expr.cond]/7.1); both were an int (0.127)
#include <cstdio>
#include <iostream>
#include <type_traits>
#include <algorithm>
#include <vector>

void f(int) { std::printf("f int\n"); }
void f(bool) { std::printf("f bool\n"); }
void g(int) { std::printf("g int\n"); }
void g(char) { std::printf("g char\n"); }
void h(int) { std::printf("h int\n"); }
void h(short) { std::printf("h short\n"); }

struct P { int v; };
bool operator<(const P &a, const P &b) { return a.v < b.v; }
int operator==(const P &a, const P &b) { return a.v == b.v ? 7 : 0; }   // a program's comparison may answer anything

template <class T> const char *kind(T) { return std::is_same_v<T, bool> ? "bool" : std::is_same_v<T, int> ? "int" : "other"; }

int main(int argc, char **) {
  int x = 1, y = 2;
  bool c = argc > 0;
  std::cout << std::boolalpha << (x < y) << " " << (x == y) << " " << !x << " " << (x && y) << " " << (x || y) << "\n";
  std::cout << std::noboolalpha << (x < y) << " " << (x >= y) << "\n";
  auto b = x < y;
  std::printf("%zu %zu %zu %zu\n", sizeof(b), sizeof(x != y), sizeof(!x), sizeof(x && y));
  f(x < y); f(!x); f(x && y); f(x || y); f(x);
  std::printf("%s %s %s\n", kind(x <= y), kind(!c), kind(x + y));
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype(x < y), bool>, (int) std::is_same_v<decltype(!x), bool>, (int) std::is_same_v<decltype(x || y), bool>);
  int n = (x < y) + (x < y);
  std::printf("%d %d %d\n", n, (x < y) * 7, (int) std::is_same_v<decltype((x < y) + 1), int>);
  bool arr[3] = {x < y, x > y, !c};
  std::printf("%d %d %d\n", arr[0], arr[1], arr[2]);
  std::printf("%d\n", std::max(x < y, y < x));
  std::vector<bool> vb;
  vb.push_back(x < y);
  vb.push_back(x > y);
  std::printf("%zu %d %d\n", vb.size(), (int) vb[0], (int) vb[1]);
  // the conditional
  std::cout << (c ? 'Y' : 'N') << (c ? '!' : '?') << "\n";
  auto ch = c ? 'a' : 'b';
  short s1 = 3, s2 = 4;
  auto sh = c ? s1 : s2;
  std::printf("%zu %zu %zu %zu\n", sizeof(ch), sizeof(sh), sizeof(c ? 1.5f : 2.5f), sizeof(c ? 'a' : 1));
  g(c ? 'a' : 'b'); g(c ? 'a' : 1);
  h(c ? s1 : s2); h(c ? s1 : 5);
  std::cout << (c ? x < y : x > y) << " " << std::boolalpha << (c ? x < y : x > y) << "\n";
  std::printf("%d %d\n", (int) std::is_same_v<decltype(c ? 'a' : 'b'), char>, (int) std::is_same_v<decltype(c ? s1 : 5), int>);
  // a class's comparison answers what its operator declares
  P p1{1}, p2{2};
  std::printf("%d %d %s\n", (int) (p1 < p2), p1 == p1, kind(p1 == p1));
  return (x < y) ? 0 : 1;
}

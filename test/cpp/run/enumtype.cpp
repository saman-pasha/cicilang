// An enumerator is of its enum's type ([dcl.enum]/5) and a prvalue; an enum promotes to its
// underlying type; a scoped enum converts to no arithmetic type implicitly (0.127). The
// enumerator was an int: `h(Red)' called `h(int)', `k(Fruit::Pear)' `k(long)', a template
// deduced an int, and `v.push_back(Green)' was refused (`undeclared(Green)').
#include <cstdio>
#include <iostream>
#include <type_traits>
#include <vector>
#include <algorithm>

enum Color { Red, Green, Blue };
enum class Fruit : short { Apple = 3, Pear };
enum Small : unsigned char { Lo = 1, Hi = 72 };   // `std::cout << Hi' is the unsigned char inserter: the H

void h(int) { std::printf("h int\n"); }
void h(Color) { std::printf("h Color\n"); }
void k(long) { std::printf("k long\n"); }
void k(Fruit) { std::printf("k Fruit\n"); }
void m(int) { std::printf("m int\n"); }
void m(unsigned char) { std::printf("m uchar\n"); }
void m(long) { std::printf("m long\n"); }
template <class T> void show(T) { std::printf("enum %d size %zu\n", (int) std::is_enum_v<T>, sizeof(T)); }
int take(const Color &c) { return (int) c + 10; }

struct Shape {
  enum Kind { Circle = 5, Square };
  Kind kind = Square;
  static const char *name(Kind k) { return k == Circle ? "circle" : "square"; }
  static const char *name(int) { return "int"; }
};

int main() {
  h(Red); h(Green); h(0); h(Red + 1);
  k(Fruit::Pear);
  m(Hi); m(Lo + 0);
  show(Red); show(Fruit::Apple); show(Hi); show(Shape::Circle);
  auto a = Green;
  std::printf("%d %d %d\n", (int) std::is_same_v<decltype(a), Color>, (int) std::is_same_v<decltype(Red), Color>, (int) std::is_same_v<decltype(Red + 1), int>);
  std::cout << Red << " " << Blue << " " << Hi << " " << (int) Fruit::Pear << "\n";
  std::vector<Color> v;
  v.push_back(Green);
  v.push_back(Red);
  v.emplace_back(Blue);
  std::printf("%d %d %d %zu\n", (int) v[0], (int) v[1], (int) v[2], v.size());
  std::printf("%d %d\n", take(Blue), (int) std::max(Red, Blue));
  std::vector<Fruit> f{Fruit::Pear, Fruit::Apple};
  std::sort(f.begin(), f.end());
  std::printf("%d %d %zu\n", (int) f[0], (int) f[1], sizeof(Fruit::Pear));
  int n = Green + Blue;
  std::printf("%d %d\n", n, Hi + 100);
  Shape s;
  std::printf("%s %s %s\n", Shape::name(Shape::Circle), Shape::name(s.kind), Shape::name(7));
  return 0;
}

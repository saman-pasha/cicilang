// A function-local static object is constructed the first time control passes its declaration, once, and destroyed
// after main ([stmt.dcl]/3, [basic.start.term]; 0.112)
#include <cstdio>
#include <string>
int made = 0;
struct Tag {
  int id;
  Tag(int k) : id(k) { ++made; std::printf("make %d\n", id); }
  ~Tag() { std::printf("drop %d\n", id); }
};
const std::string &name() {
  static std::string s = std::string("na") + "me";
  return s;
}
int counter() {
  static Tag t(7);
  return ++t.id;
}
int main() {
  std::printf("start %d\n", made);
  int a = counter();
  int b = counter();
  std::printf("%d %d %d\n", a, b, made);
  const std::string &n1 = name();
  const std::string &n2 = name();
  std::printf("%s %d\n", n1.c_str(), (int) (&n1 == &n2));
  return 0;
}

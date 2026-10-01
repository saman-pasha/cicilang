// A temporary bound to a named reference lives as long as the reference ([class.temporary]/6; 0.112)
#include <cstdio>
#include <string>
int made = 0, gone = 0;
struct Tag {
  int id;
  Tag(int k) : id(k) { ++made; std::printf("make %d\n", id); }
  Tag(const Tag &o) : id(o.id + 100) { ++made; std::printf("copy %d\n", id); }
  ~Tag() { ++gone; std::printf("drop %d\n", id); }
};
Tag make(int k) { return Tag(k); }
std::string greet() { return std::string("hello, ") + "world"; }
int main() {
  {
    const Tag &a = Tag(1);
    std::printf("bound %d\n", a.id);
    Tag &&b = make(2);
    b.id += 10;
    std::printf("bound %d %d\n", a.id, b.id);
  }
  std::printf("after %d %d\n", made, gone);
  {
    const std::string &s = greet();
    std::string &&t = std::string("abc") + "def";
    std::printf("%s %s %d\n", s.c_str(), t.c_str(), (int) (s.size() + t.size()));
  }
  return 0;
}

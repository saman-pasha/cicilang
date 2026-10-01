// A local initialized by a call of a temporary: the temporary built once and destroyed once
#include <cstdio>
struct Tag {
  int id;
  Tag(int k) : id(k) { std::printf("make %d\n", id); }
  Tag(const Tag &o) : id(o.id + 100) { std::printf("copy %d\n", id); }
  ~Tag() { std::printf("drop %d\n", id); }
};
Tag plus(const Tag &a, int k) { return Tag(a.id + k); }
int main() {
  Tag t = plus(Tag(1), 5);
  std::printf("t %d\n", t.id);
  return 0;
}

// A global whose constructor cannot run at compile time is constructed before main, in declaration order, and
// destroyed after main in the reverse order ([basic.start.dynamic], [basic.start.term]; 0.112)
#include <cstdio>
#include <string>
#include <vector>
int made = 0;
struct Tag {
  int id;
  Tag(int k) : id(k * 10 + ++made) { std::printf("make %d\n", id); }
  Tag() : Tag(9) {}
  ~Tag() { std::printf("drop %d\n", id); }
};
Tag first(1);
std::string name = "global";
Tag second;
std::vector<int> nums = {1, 2, 3};
static Tag third = Tag(3);
int main() {
  nums.push_back(4);
  name += " string";
  std::printf("main %d %d %d %s %d\n", first.id, second.id, third.id, name.c_str(), (int) nums.size());
  return 0;
}

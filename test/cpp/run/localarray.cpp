// A local array of objects (0.112): each element constructed in order -- from its item, a prvalue of the class being
// the element, else the default constructor -- and destroyed in reverse at the scope's end
#include <cstdio>
#include <string>
int made = 0, gone = 0;
struct Tag {
  int id;
  Tag() : id(++made) { std::printf("make %d\n", id); }
  Tag(int k) : id(k) { ++made; std::printf("make %d\n", id); }
  ~Tag() { ++gone; std::printf("drop %d\n", id); }
};
struct Plain { int a = 7; int b; };
int main() {
  {
    Tag ts[3];
    std::printf("in %d %d %d\n", ts[0].id, ts[1].id, ts[2].id);
  }
  {
    Tag us[3] = {Tag(10), Tag(20)};
    std::printf("in %d %d %d\n", us[0].id, us[1].id, us[2].id);
  }
  {
    std::string names[3] = {"ann", "bob"};
    names[2] = "cyd";
    std::printf("%s %s %s %d\n", names[0].c_str(), names[1].c_str(), names[2].c_str(), (int) names[1].size());
  }
  Plain ps[2];
  std::printf("%d %d %d %d\n", made, gone, ps[0].a, ps[1].a);
  return 0;
}

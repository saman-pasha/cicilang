// decltype(auto) and auto&& keep the value category of what they are given
#include <cstdio>
#include <string>
#include <utility>
#include <vector>

decltype(auto) first(std::vector<int> &v) { return v[0]; }        // int &
decltype(auto) copy_of(int x) { return x; }                         // int
decltype(auto) take(std::string &s) { return std::move(s); }       // std::string &&

struct Box {
  int data_[3] = {1, 2, 3};
  decltype(auto) at(int i) { return data_[i]; }                     // int &
  decltype(auto) size() const { return 3; }                          // int
};

const char *which(int &) { return "lvalue"; }
const char *which(int &&) { return "rvalue"; }

template <class T> const char *fwd(T &&t) { return which(std::forward<T>(t)); }

int make() { return 40; }

int main() {
  std::vector<int> v{5, 6, 7};
  first(v) = 50;
  std::printf("%d %d\n", v[0], copy_of(9));

  std::string s = "moved away";
  std::string t = take(s);
  std::printf("[%s] [%s]\n", s.c_str(), t.c_str());

  Box b;
  b.at(1) = 20;
  std::printf("%d %d %d\n", b.data_[1], b.size(), (int) sizeof(b.size()));

  auto get = [&v]() -> decltype(auto) { return v[2]; };
  get() = 70;
  auto &&r = v[1];
  r = 60;
  std::printf("%d %d %d\n", v[0], v[1], v[2]);
  std::printf("%s %s\n", which(std::forward<decltype(r)>(r)), fwd(r));

  auto &&p = make();
  p += 2;
  decltype(auto) d = v[0];
  d += 1;
  std::printf("%d %d\n", p, v[0]);

  auto gen = [](auto &c) -> decltype(auto) { return c.front(); };
  gen(v) = 1;
  std::printf("%d\n", v[0]);
  return 0;
}

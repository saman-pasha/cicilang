// a free function returning a reference: its result is typed as declared, an lvalue or an xvalue
#include <cstdio>
#include <string>
#include <utility>

std::string &get(std::string &s) { return s; }
std::string &&take(std::string &s) { return std::move(s); }
const std::string &pick(const std::string &a, const std::string &b) { return a.size() >= b.size() ? a : b; }
std::string make() { return "made"; }

int main() {
  std::string s = "kept";
  std::string t = get(s);
  t += "!";
  get(s) += "?";
  std::string u = make();
  std::printf("[%s] [%s] [%s] %d\n", s.c_str(), t.c_str(), u.c_str(), (int) get(s).size());
  std::string w = "moved away";
  std::string x = take(w);
  std::printf("[%s] [%s]\n", w.c_str(), x.c_str());
  std::printf("[%s] %d\n", pick(s, x).c_str(), (int) pick(u, s).size());
  return 0;
}

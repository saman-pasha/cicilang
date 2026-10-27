// static data members of library classes (0.218): defined out of the class -- a vector, a string with an initializer, a map
// -- and inline in the class with no initializer -- a vector, a string, an int --, used from static and non-static
// members and from main; each constructed before main and destroyed at exit
#include <cstdio>
#include <map>
#include <string>
#include <vector>
struct K {
  static std::vector<int> all;
  static std::string name;
  static std::map<int, int> squares;
  static inline std::vector<int> later;
  static inline std::string word;
  static inline int count;
  static void reg(int p) { all.push_back(p); squares[p] = p * p; ++count; }
  void note(int p) { later.push_back(p); word += 'a' + p; }
  static std::size_t size() { return all.size() + later.size(); }
};
std::vector<int> K::all;
std::string K::name = "abc";
std::map<int, int> K::squares;
int main() {
  K::reg(3);
  K::reg(4);
  K k;
  k.note(1);
  k.note(2);
  std::printf("%zu %d %d %s %zu %d %s %d\n", K::size(), K::all[1], K::squares[4], K::name.c_str(), K::later.size(), K::later[1], K::word.c_str(), K::count);
  return 0;
}

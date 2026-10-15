// std::filesystem::path: construction, decomposition, concatenation, comparison.
#include <cstdio>
#include <filesystem>
#include <string>
namespace fs = std::filesystem;
int main() {
  fs::path p("/usr/lib/libc.so.6");
  std::printf("%s|%s|%s|%s|%s\n", p.filename().c_str(), p.stem().c_str(), p.extension().c_str(),
              p.parent_path().c_str(), p.root_path().c_str());
  fs::path q = fs::path("a") / "b" / "c.txt";
  q.replace_extension(".md");
  std::printf("%s %d %d\n", q.c_str(), (int) q.is_relative(), (int) (q == fs::path("a/b/c.md")));
  std::string s = (fs::path("x") / "y").string();
  std::printf("%s %zu\n", s.c_str(), s.size());
  return 0;
}

// std::filesystem operations: create a directory, write a file, list it, file_size, exists, remove_all.
#include <cstdio>
#include <filesystem>
#include <fstream>
namespace fs = std::filesystem;
int main() {
  fs::path d = fs::temp_directory_path() / "cicilang_fsops_fixture";
  fs::remove_all(d);
  fs::create_directories(d / "sub");
  { std::ofstream(d / "a.txt") << "hello"; }
  std::printf("%d %d %llu\n", (int) fs::exists(d / "a.txt"), (int) fs::is_directory(d / "sub"),
              (unsigned long long) fs::file_size(d / "a.txt"));
  int n = 0;
  for (const auto &e : fs::directory_iterator(d)) { (void) e; n++; }
  std::printf("%d %d\n", n, (int) fs::remove_all(d));
  return 0;
}

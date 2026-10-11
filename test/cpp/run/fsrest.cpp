// the rest of <filesystem> (C++17): recursive_directory_iterator, permissions, last_write_time, space, file_size,
// copy_file, rename, remove_all
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
namespace fs = std::filesystem;
int main() {
  fs::path root = fs::temp_directory_path() / "cicilang_fsrest";
  fs::remove_all(root);
  fs::create_directories(root / "a" / "b");
  { std::ofstream(root / "a" / "one.txt") << "hello"; }
  { std::ofstream(root / "a" / "b" / "two.txt") << "worlds!"; }
  std::vector<std::string> names;
  for (const auto &e : fs::recursive_directory_iterator(root)) names.push_back(fs::relative(e.path(), root).generic_string());
  std::sort(names.begin(), names.end());
  for (const auto &n : names) std::printf("%s ", n.c_str());
  std::printf("\n");
  std::printf("%d %d\n", (int) fs::file_size(root / "a" / "one.txt"), (int) fs::file_size(root / "a" / "b" / "two.txt"));
  fs::permissions(root / "a" / "one.txt", fs::perms::owner_read | fs::perms::owner_write, fs::perm_options::replace);
  auto p = fs::status(root / "a" / "one.txt").permissions();
  std::printf("%o\n", (unsigned) (p & fs::perms::all));
  auto t0 = fs::last_write_time(root / "a" / "one.txt");
  fs::last_write_time(root / "a" / "one.txt", t0 - std::chrono::hours(1));
  auto t1 = fs::last_write_time(root / "a" / "one.txt");
  std::printf("%lld\n", (long long) std::chrono::duration_cast<std::chrono::minutes>(t0 - t1).count());
  fs::space_info si = fs::space(root);
  std::printf("%d\n", (int) (si.capacity >= si.free && si.free >= si.available));
  fs::copy_file(root / "a" / "one.txt", root / "copy.txt");
  fs::rename(root / "copy.txt", root / "moved.txt");
  std::printf("%d %d\n", (int) fs::exists(root / "copy.txt"), (int) fs::exists(root / "moved.txt"));
  std::printf("%d\n", (int) fs::remove_all(root));
  return 0;
}

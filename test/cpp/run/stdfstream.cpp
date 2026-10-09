// std::ofstream, std::ifstream and std::fstream (0.117): a class derived from basic_ostream (a virtual base basic_ios) whose own data
// member is the filebuf, so the members the shipped library exports for it (`open') must not be called -- the program's layout puts
// the filebuf where the shipped function would not look. Constructed from a path, written, read back by getline and by `>>', appended,
// read and rewritten through an fstream, seeked, a file that is not there, and the C library's remove beside the filesystem's.
#include <fstream>
#include <iostream>
#include <string>
#include <cstdio>
int main() {
  const char *path = "/tmp/cicilang_stdfstream.tmp";
  {
    std::ofstream out(path);
    out << "line one\nline two\n" << 7 << ' ' << 2.5 << "\n";
    out << std::hex << 255 << std::dec << '\n';
  }
  {
    std::ifstream in(path);
    std::string a, b; int n = 0; double d = 0;
    std::getline(in, a); std::getline(in, b); in >> n >> d;
    std::cout << a << '|' << b << '|' << n << '|' << d << '\n';
    std::string rest; std::getline(in, rest); std::getline(in, rest);
    std::cout << "[" << rest << "]\n";
    in.clear(); in.seekg(0, std::ios_base::beg);
    std::getline(in, a);
    std::cout << a << ' ' << in.tellg() << '\n';
  }
  { std::ofstream app(path, std::ios_base::app); app << "appended\n"; }
  { std::ifstream in(path); std::string line; int count = 0; while (std::getline(in, line)) ++count; std::cout << count << " lines\n"; }
  { std::fstream rw(path, std::ios_base::in | std::ios_base::out); std::string first; std::getline(rw, first); rw.seekp(0); rw << "LINE"; rw << std::flush; }
  { std::ifstream in(path); std::string l; std::getline(in, l); std::cout << l << ' ' << in.tellg() << '\n'; std::cout << in.rdbuf(); }
  { std::ifstream missing("/tmp/cicilang_no_such_file.tmp"); std::cout << missing.is_open() << missing.fail() << '\n'; }
  { std::ofstream o2; o2.open(path); std::cout << o2.is_open(); o2 << "x"; o2.close(); std::cout << o2.is_open() << '\n'; }
  std::remove(path);
  return 0;
}

// std::stringstream and its relatives (0.117): libc++'s basic_iostream is a DIAMOND over the virtual base basic_ios -- basic_istream and
// basic_ostream both derive from it -- so a stringstream is built with the base-variant constructors of two LIBRARY classes (C2),
// and the free inserters (`ss << "x"') reach basic_ostream, the SECOND base of basic_iostream. Reading and writing through the one
// object, the base references (istream &, ostream &, iostream &, ios &), a pointer to the iostream, tellp/tellg/seek, and the single-path
// ostringstream and istringstream beside it.
#include <sstream>
#include <iostream>
#include <string>
static void put(std::ostream &o, int v) { o << "<" << v << ">"; }
static int get(std::istream &i) { int v = 0; i >> v; return v; }
static void both(std::iostream &s) { s << 7 << ' '; int v; s >> v; std::cout << "both " << v << '\n'; }
static bool good(std::ios &s) { return s.good(); }
int main() {
  std::stringstream ss("10 20 30");
  int sum = 0, n;
  while (ss >> n) sum += n;
  std::cout << "sum " << sum << ' ' << ss.eof() << ss.fail() << '\n';
  ss.clear(); ss.str("");
  put(ss, 5); put(ss, 6);
  std::cout << ss.str() << '\n';
  std::stringstream t;
  t << "42 rest of line\nsecond";
  std::cout << get(t) << '\n';
  std::string line;
  std::getline(t, line);
  std::cout << "[" << line << "]\n";
  std::getline(t, line);
  std::cout << "[" << line << "]\n";
  std::stringstream u;
  both(u);
  std::cout << good(u) << '\n';
  u.seekg(0); u.seekp(0, std::ios_base::end);
  u << "tail";
  std::cout << u.str() << " " << u.tellp() << " " << u.tellg() << '\n';
  std::stringstream w;
  w << std::hex << 255 << ' ' << std::dec << 255 << ' ' << 1.5 << ' ' << true;
  std::cout << w.str() << '\n';
  std::iostream *p = &w;
  *p << " more";
  std::cout << w.str() << '\n';
  std::ostringstream os; os << "os " << 1; std::istringstream is("5 6"); int a, b; is >> a >> b;
  std::cout << os.str() << ' ' << a + b << '\n';
  std::wstringstream ws;                                   // a diamond libc++ does not ship for wchar_t: its path destructors are empty
  ws << L"wide " << 42 << L' ' << 1.5;
  std::wstring wword; int wn; double wd;
  ws >> wword >> wn >> wd;
  std::wcout << wword << L' ' << wn << L' ' << wd << L'\n';
  std::stringstream csv("a,b,,d");
  std::string cell; int cells = 0;
  while (std::getline(csv, cell, ',')) { ++cells; std::cout << "<" << cell << ">"; }
  std::cout << cells << '\n';
  std::istringstream is2("abc def");
  std::cout << is2.rdbuf() << '\n';                         // basic_stringbuf * to basic_streambuf *, better than to const void *
  std::stringstream sp("   spaced");
  sp >> std::ws; std::string word; sp >> word; std::cout << word << '\n';
  return 0;
}

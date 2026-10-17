// A PROGRAM CLASS OVER TWO LIBRARY CLASSES THAT SHARE A VIRTUAL BASE (0.160): std::istream and std::ostream over one basic_ios
#include <cstdio>
#include <istream>
#include <ostream>
#include <sstream>
struct X : std::istream, std::ostream {
  int n = 3;
  explicit X(std::streambuf *sb) : std::istream(sb), std::ostream(sb) {}
};
static int take(std::istream &in) { int v = 0; in >> v; return v; }
static void put(std::ostream &out, int v) { out << "v=" << v << ';'; }
int main() {
  std::stringbuf sb("42 7 9 ");
  X x(&sb);
  int a = 0, b = 0;
  x >> a >> b;
  int c = take(x);
  x << "sum " << a + b + c << '\n';
  put(x, x.n);
  std::ios &io = x;
  std::printf("%d %d %d %d %d [%s]\n", a, b, c, (int) x.good(), (int) io.good(), sb.str().c_str());
  return 0;
}

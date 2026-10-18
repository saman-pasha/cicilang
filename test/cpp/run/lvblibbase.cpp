// a LIBRARY class with a virtual base as a later virtual base of the program's class (0.173): X : B, virtual std::istream
#include <cstdio>
#include <istream>
#include <sstream>
struct B { int b = 3; virtual int fb() { return 30 + b; } virtual ~B() {} };
struct X : B, virtual std::istream { int x = 4; X(std::streambuf *sb) : std::istream(sb) {} };
int main() {
    std::stringbuf sb("12 34");
    { X x(&sb); int a = 0, c = 0; x >> a >> c; std::printf("%d %d %d %d %d\n", a, c, x.b, x.x, x.fb());
      std::istream &is = x; int d = 7; is >> d; std::printf("%d %d\n", d, (bool) is); }
    return 0;
}

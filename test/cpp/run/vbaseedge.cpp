// edge shapes of the Itanium layout over a virtual base (0.163): an EMPTY virtual base (at offset 0, no place of its own), a
// holder whose last member leaves tail padding that a derived class's member takes, a copy and an assignment of a holder's
// sub-object (the virtual base read through the source's table), and a program class over a library holder (an ostringstream)
#include <cstdio>
#include <sstream>
#include <string>
struct EV {};
struct EB : virtual EV { int b = 2; };
struct EC : EB { int c = 3; };
struct V { int v = 1; virtual ~V() {} };
struct TQ : virtual V { int q = 4; };
struct TP : TQ { char c = 'p'; };
struct TE : TP { char e = 'e'; };
struct S { std::string s = "s"; };
struct SQ : virtual S { int q = 5; };
struct SD : SQ { std::string d = "d"; };
struct SE : SD { int e = 6; };
struct L : std::ostringstream { int n = 7; };
static long off(const void *o, const void *m) { return (const char *) m - (const char *) o; }
int main() {
  EC ec; TE te; TP tp;
  std::printf("empty %zu %zu %ld %ld\n", sizeof(EB), sizeof(EC), off(&ec, &ec.b), off(&ec, &ec.c));
  std::printf("tail %zu %zu %zu %ld %ld %ld %ld\n", sizeof(TQ), sizeof(TP), sizeof(TE), off(&tp, &tp.c), off(&te, &te.c), off(&te, &te.e), off(&te, &te.v));
  SE se; se.s = "long string that is not short"; se.d = "dee"; se.q = 50; se.e = 60;
  SD sd = se;
  std::printf("copy %s %s %d\n", sd.s.c_str(), sd.d.c_str(), sd.q);
  SD sd2; sd2 = se;
  std::printf("assign %s %s %d\n", sd2.s.c_str(), sd2.d.c_str(), sd2.q);
  SE se2 = se;
  std::printf("copy2 %s %s %d %d\n", se2.s.c_str(), se2.d.c_str(), se2.q, se2.e);
  L l; l << "x" << 3 << ' ' << l.n;
  std::printf("lib %s %zu\n", l.str().c_str(), sizeof(L) - sizeof(std::ostringstream));
  std::ostringstream &r = l; r << '!';
  std::printf("lib2 %s\n", l.str().c_str());
  return 0;
}

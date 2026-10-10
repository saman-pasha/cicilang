// An integral or floating PROMOTION is a better conversion than any other ([over.ics.rank]/4.2,
// [conv.prom], [conv.fpprom]); this compiler ranked them alike and took the first declared (0.127)
#include <cstdio>
#include <iostream>
#include <string>

enum Color { Red, Green };
void p(long) { std::printf("p long\n"); }
void p(int) { std::printf("p int\n"); }
void q(double) { std::printf("q double\n"); }
void q(int) { std::printf("q int\n"); }
void r(unsigned) { std::printf("r unsigned\n"); }
void r(int) { std::printf("r int\n"); }
void s(bool) { std::printf("s bool\n"); }
void s(int) { std::printf("s int\n"); }
void t(int) { std::printf("t int\n"); }
void t(double) { std::printf("t double\n"); }
void u(long) { std::printf("u long\n"); }
void u(unsigned) { std::printf("u unsigned\n"); }

struct Sink {
  const char *put(long) const { return "put long"; }
  const char *put(int) const { return "put int"; }
  const char *put(double) const { return "put double"; }
};

int main() {
  short sh = 3; char ch = 'a'; unsigned char uc = 7; bool b = true; float f = 1.5f;
  unsigned short us = 9; char16_t c16 = u'x'; char32_t c32 = U'y'; wchar_t wc = L'z';
  Color c = Green;
  p(sh); p(ch); p(uc); p(b); p(us); p(c16); p(c);
  q(sh); q(c); q(wc);
  r(sh); r(uc);
  s(sh); s(c);
  t(f); t(sh);
  u(c32);
  const Sink k{};
  std::printf("%s %s %s\n", k.put(sh), k.put(f), k.put(c));
  std::cout << c << " " << sh << " " << b << " " << f << "\n";
  std::cout << std::to_string(ch) << " " << std::to_string(b) << "\n";
  return 0;
}

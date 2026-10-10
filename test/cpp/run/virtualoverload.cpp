// Two virtual overloads of one name and arity are two slots; a derived class overrides one of them.
#include <cstdio>
#include <string>
struct B {
  virtual ~B() { }
  virtual int put(int, long double v) const { std::printf("B ld %.1Lf\n", v); return 1; }
  virtual int put(int, const std::string &s) const { std::printf("B str %s\n", s.c_str()); return 2; }
  int go(int k, const std::string &s) const { return put(k, s); }
  int go(int k, long double v) const { return put(k, v); }
};
struct D : B {
  int put(int, const std::string &s) const override { std::printf("D str %s\n", s.c_str()); return 20; }
};
int main() {
  D d; const B &b = d;
  int r1 = b.go(1, std::string("x"));
  int r2 = b.go(1, 2.5L);
  B e;
  int r3 = e.go(0, std::string("y"));
  int r4 = e.go(0, 1.5L);
  std::printf("%d %d %d %d\n", r1, r2, r3, r4);
  return 0;
}

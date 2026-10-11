#include <cstdio>
struct V {
  virtual ~V() {}
  virtual int f() const { return 1; }
  virtual int g(int k) const { return 10 + k; }
};
struct L : virtual V {
  int f() const override { return 2; }
};
struct M : L {
  int f() const override { return 3; }
  int g(int k) const override { return 30 + k; }
};
struct R : virtual V {
  int g(int k) const override { return 40 + k; }
};
struct D : L, R {
  int f() const override { return 5; }
};
int callL(const L &x) { return x.f() * 100 + x.g(1); }
int callR(const R *x) { return x->f() * 100 + x->g(2); }
int main() {
  M m;
  D d;
  L l;
  const L *p = &m;
  std::printf("%d %d %d\n", p->f(), p->g(0), callL(m));
  std::printf("%d %d %d\n", callL(d), callR(&d), callL(l));
  return 0;
}

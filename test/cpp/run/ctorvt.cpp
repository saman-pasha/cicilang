// Construction vtables: a virtual call in a diamond's path constructor or destructor reaches the PATH's override, not
// the most-derived one ([class.cdtor]/4), and the path still reaches the shared virtual base's data through its table
#include <cstdio>
struct V {
  int tag;
  V() : tag(7) {}
  virtual ~V() {}
  virtual const char *who() const { return "V"; }
};
struct L;
struct R;
const char *viaL(const L *p);
const char *viaR(const R *p);
const char *viaV(const V *p) { return p->who(); }
struct L : virtual V {
  int l;
  L() : l(1) { std::printf("L() sees %s %s %s, tag %d\n", who(), viaL(this), viaV(this), tag); }
  ~L() override { std::printf("~L() sees %s %s %s, tag %d\n", who(), viaL(this), viaV(this), tag); }
  const char *who() const override { return "L"; }
};
struct R : virtual V {
  int r;
  R() : r(2) { std::printf("R() sees %s %s %s, tag %d\n", who(), viaR(this), viaV(this), tag); }
  ~R() override { std::printf("~R() sees %s %s %s, tag %d\n", who(), viaR(this), viaV(this), tag); }
  const char *who() const override { return "R"; }
};
const char *viaL(const L *p) { return p->who(); }
const char *viaR(const R *p) { return p->who(); }
struct D : L, R {
  int d;
  D() : d(3) { std::printf("D() sees %s\n", who()); }
  ~D() override { std::printf("~D() sees %s\n", who()); }
  const char *who() const override { return "D"; }
};
int main() {
  {
    D x;
    V &v = x;
    std::printf("through V: %s, %d %d %d %d\n", v.who(), x.l, x.r, x.d, x.tag);
  }
  L y;
  std::printf("alone: %s\n", y.who());
  return 0;
}

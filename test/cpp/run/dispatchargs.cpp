// a virtual call's arguments take the passes a direct call does: a class value to a scalar parameter through its
// conversion operator, and a class taken by value copied at the call and destroyed by the callee
#include <cstdio>
struct Pos { long v; Pos(long x) : v(x) {} operator long() const { return v; } };
struct T { int v; static int made, gone; T(int x) : v(x) { made++; } T(const T &o) : v(o.v) { made++; } ~T() { gone++; } };
int T::made = 0, T::gone = 0;
struct B {
  virtual ~B() {}
  virtual long off(long o, int w) { return o + w; }
  virtual Pos pos(Pos p, int w) { Pos r = this->off(p, w); return r; }
  long plain(long o) { return o * 2; }
  long both(Pos p) { return plain(p) + off(p, 1); }
  virtual int take(T t) { return t.v; }
  int twice(T t) { return take(t) * 2; }
};
struct D : B {
  long off(long o, int w) override { return o * 10 + w; }
  int take(T t) override { return t.v + 100; }
};
int main() {
  B b; D d; Pos p(5);
  std::printf("%ld %ld %ld %ld\n", (long) b.pos(p, 2), (long) d.pos(p, 2), b.both(p), d.both(p));
  B *q = &d; std::printf("%ld\n", q->off(p, 3));
  {
    T a(5);
    int r = q->take(a); std::printf("%d %d %d\n", r, T::made, T::gone);
    int s = q->take(7); std::printf("%d %d %d\n", s, T::made, T::gone);
    int u = d.twice(a); std::printf("%d %d %d\n", u, T::made, T::gone);
  }
  std::printf("%d %d\n", T::made, T::gone);
  return 0;
}

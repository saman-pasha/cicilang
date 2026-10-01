// A designated temporary `T{.a = 1}' keeps its designators: a plain struct's as a compound literal, an aggregate
// class's member by member, a hole from its default member initializer; a designator may name a member of an
// anonymous union, and `return {.a = 1}' designates the result (0.112) -- libc++'s std::format builds its parsed
// specifications so
#include <cstdio>
enum class Al : unsigned char { a, b, c };
struct Std { Al al : 3; bool f : 1; unsigned char t; };
struct Chr { Al al : 3; bool g : 1; unsigned char u; };
struct Plain {
  union {
    Al al : 3;
    Std std_;
    Chr chr_;
  };
  int width;
  int prec;
};
template <class C> struct Point { C data[4] = {'#'}; };
template <class C> struct Parsed {
  union {
    Al al : 3;
    Std std_;
    Chr chr_;
  };
  int width;
  int prec = 6;
  Point<C> fill;
};
Plain plain(int w) { return Plain{.std_ = Std{.al = Al::b, .f = true, .t = 7}, .width = w, .prec = 3}; }
template <class C> Parsed<C> make(int w, Point<C> f) {
  return Parsed<C>{.std_ = Std{.al = Al::b, .f = true, .t = 7}, .width{w}, .fill{f}};
}
template <class C> Parsed<C> make2() { return {.chr_ = Chr{.al = Al::c, .g = true, .u = 9}, .prec = 2}; }
int main() {
  Plain a = plain(5);
  std::printf("%d %d %d %d %d %d\n", (int) a.std_.al, (int) a.std_.f, a.std_.t, a.width, a.prec, (int) a.al);
  Plain b{.chr_ = Chr{.al = Al::c, .g = false, .u = 9}, .width = 1, .prec = 2};
  std::printf("%d %d %d %d\n", (int) b.chr_.al, b.chr_.u, b.width, (int) b.al);
  Point<char> f{{'x', 'y'}};
  Parsed<char> p = make<char>(5, f);
  std::printf("%d %d %d %d %d %d %c%c\n", (int) p.std_.al, (int) p.std_.f, p.std_.t, p.width, p.prec, (int) p.al, p.fill.data[0], p.fill.data[1]);
  Parsed<char> q = make2<char>();
  std::printf("%d %d %d %d %d %c\n", (int) q.chr_.al, (int) q.chr_.g, q.chr_.u, q.width, q.prec, q.fill.data[0]);
  Parsed<char> r{.al = Al::c, .width = 4};
  std::printf("%d %d %d %c\n", (int) r.al, r.width, r.prec, r.fill.data[0]);
  return 0;
}

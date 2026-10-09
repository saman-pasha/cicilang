// the memory algorithms a program calls itself: construct_at, destroy_at, destroy, destroy_n, uninitialized_copy,
// uninitialized_fill, uninitialized_move, uninitialized_default_construct, uninitialized_value_construct (and _n forms),
// over raw storage from std::allocator and over a type with a visible constructor and destructor
#include <cstdio>
#include <memory>
#include <string>
struct Tr { int v; Tr() : v(1) { std::printf("Tr()\n"); } Tr(int x) : v(x) { std::printf("Tr(%d)\n", x); } Tr(const Tr &o) : v(o.v + 100) { std::printf("copy %d\n", o.v); } ~Tr() { std::printf("~Tr %d\n", v); } };
int main() {
  std::allocator<Tr> a;
  Tr *p = a.allocate(4);
  Tr src[3] = {Tr(1), Tr(2), Tr(3)};
  std::printf("-- copy\n");
  std::uninitialized_copy(src, src + 3, p);
  std::printf("-- fill\n");
  std::uninitialized_fill(p + 3, p + 4, Tr(9));
  std::printf("-- values %d %d %d %d\n", p[0].v, p[1].v, p[2].v, p[3].v);
  std::destroy(p, p + 4);
  std::printf("-- fill_n\n");
  std::uninitialized_fill_n(p, 2, Tr(5));
  std::destroy_n(p, 2);
  std::printf("-- default\n");
  std::uninitialized_default_construct(p, p + 2);
  std::destroy_at(p + 1);
  std::destroy_at(p);
  std::printf("-- value\n");
  std::uninitialized_value_construct_n(p, 2);
  std::destroy(p, p + 2);
  std::printf("-- construct_at\n");
  Tr *q = std::construct_at(p + 2, 42);
  std::printf("%d\n", q->v);
  std::destroy_at(q);
  a.deallocate(p, 4);
  std::allocator<std::string> sa;
  std::string *s = sa.allocate(2);
  std::string in[2] = {"alpha", "a rather longer string, beyond the short buffer of libc++"};
  std::uninitialized_move(in, in + 2, s);
  std::printf("%s | %s | [%s]\n", s[0].c_str(), s[1].c_str(), in[1].c_str());
  std::destroy(s, s + 2);
  sa.deallocate(s, 2);
  std::printf("-- end\n");
  return 0;
}

// A namespace's overload set named with its namespace as a value (1.6.39; [over.over]): the target chooses, in a block, at
// namespace scope, through its address and as an argument; each value is clang++'s
#include <cstdio>
namespace n { int h(int a) { return a + 1; } int h(double d) { return (int)d + 50; } }
namespace m { namespace k { int q(int a) { return a * 2; } int q(const char *s) { return s[0]; } } }
int h(int a) { return a + 1000; }
int (*gp)(double) = n::h;
int (*gq)(const char *) = &m::k::q;
int call(int (*f)(int), int v) { return f(v); }
int main() {
  int (*ph)(int) = n::h; int (*pd)(double) = &n::h; int (*pq)(int) = m::k::q;
  std::printf("%d %d %d %d %d %d %d\n", ph(1), pd(2.5), pq(3), gp(4.5), gq("A"), call(n::h, 7), call(h, 7));
  return 0;
}

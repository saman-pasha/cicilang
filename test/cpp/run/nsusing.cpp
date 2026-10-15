// A using-declaration or a using-directive over names that two namespaces declare: a bare use after it finds the
// namespace it names, at file scope, in a namespace and in a block
#include <cstdio>
namespace a {
int f() { return 1; }
int g(int x) { return x + 10; }
struct S { int v = 3; };
namespace in { int z() { return 100; } }
}
namespace b {
int f() { return 2; }
int g(int x) { return x + 20; }
struct S { int v = 4; };
namespace in { int z() { return 200; } }
}
namespace c { int h() { return 5; } }
using b::f;
using namespace c;
int k() { using a::g; return g(1); }
int m() { using namespace b; S s; return g(2) + s.v; }
int n() { using b::S; S s; return s.v; }
int o() { using namespace b::in; return z(); }
namespace d {
using namespace b;
int p() { S s; return g(3) + s.v + f(); }
}
int main() {
  std::printf("%d %d %d %d %d\n", f(), h(), k(), m(), a::f() + b::f());
  std::printf("%d %d %d %d %d\n", n(), o(), d::p(), a::in::z(), b::in::z());
  return 0;
}

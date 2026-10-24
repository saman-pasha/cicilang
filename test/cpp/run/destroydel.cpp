#include <cstdio>
#include <cstdlib>
#include <new>
// C++20's destroying operator delete ([expr.delete]/9, P0722): `delete p' calls it and no destructor first
struct D {
  int v = 3;
  ~D() { std::printf("~D\n"); }
  void operator delete(D *p, std::destroying_delete_t) { std::printf("destroying %d\n", p->v); p->~D(); ::operator delete(p); }
};
int main() {
  D *d = new D;
  delete d;
  return 0;
}

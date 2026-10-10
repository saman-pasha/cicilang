// A downcast from a base that is not at offset zero moves the pointer back by the base's offset (static_cast, a pointer and a reference).
#include <cstdio>
struct A { int a; };
struct B { int b; };
struct D : A, B { int d; };
int get(B *pb) { D *pd = static_cast<D *>(pb); return pd->a * 100 + pd->d; }
int getr(B &rb) { D &rd = static_cast<D &>(rb); return rd.a * 100 + rd.d; }
int main() {
  D x; x.a = 7; x.b = 8; x.d = 9;
  B *pb = &x;
  std::printf("%d %d %d\n", get(pb), getr(x), (int) (static_cast<D *>(pb) == &x));
  return 0;
}

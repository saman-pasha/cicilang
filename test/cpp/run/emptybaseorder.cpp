// emptybaseorder.cpp: the empty bases in the bases' order (0.235; the Itanium ABI 2.4 II.3): a base keeps offset 0 before a later
// empty base, which moves past the data where an empty subobject of its type lies there already, a base that is not empty
// moves past one of its own, and a pointer converts to an empty base at its place -- inside a virtual base too.
extern "C" int printf(const char *, ...);
namespace e1 {
struct C0 {};
struct C1 : C0 { int m1_0 = 101; virtual int f1() { return 1001; } };
struct C3 : virtual C1 {};
int run() {
  C3 *o = new C3;
  C0 *b = o;
  C1 *c = o;
  C0 *d = c;
  printf("C0 at %d %d %d\n", (int)((char *)b - (char *)o), (int)((char *)c - (char *)o), (int)((char *)d - (char *)o));
  delete o;
  return 0;
}
}
namespace e2 {
struct E {};
struct B { int x = 1; };
struct C : E { int y = 2; };
struct D : B, C { int z = 3; };
int run() {
  D *o = new D;
  E *e = o;
  printf("E at %d\n", (int)((char *)e - (char *)o));
  delete o;
  return 0;
}
}
namespace e4 {
struct E {};
struct Y : E { int y = 5; };
struct X : E, Y { int x = 6; };
int run() {
  X *o = new X;
  Y *y = o;
  printf("size %d Y at %d y %d x %d\n", (int) sizeof(X), (int)((char *)y - (char *)o), y->y, o->x);
  delete o;
  return 0;
}
}
namespace e7 {
struct E {};
struct P { E e; int x = 4; };
struct T : P, E { int t = 5; };
struct A {};
struct B : A {};
struct I : A, B {};
int run() {
  T *o = new T;
  E *e = o;
  P *p = o;
  printf("size %d E at %d P at %d e at %d x %d t %d\n", (int) sizeof(T), (int)((char *)e - (char *)o), (int)((char *)p - (char *)o), (int)((char *)&o->e - (char *)o), o->x, o->t);
  I *i = new I;
  B *b = i;
  printf("size %d B at %d\n", (int) sizeof(I), (int)((char *)b - (char *)i));
  delete o;
  delete i;
  return 0;
}
}
int main() {
  printf("-- e1\n"); e1::run();
  printf("-- e2\n"); e2::run();
  printf("-- e4\n"); e4::run();
  printf("-- e7\n"); e7::run();
  return 0;
}

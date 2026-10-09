// Arrays of objects beyond localarray.cpp: a local array of ARRAYS of objects (constructed element by element in order,
// destroyed in reverse), a static local array of objects (constructed once, the first time control passes its
// declaration, destroyed at exit), and nested initializer lists whose items are prvalues of the element class (C++17's
// elision: the item IS the element, no temporary dies at the end of the declaration)
#include <cstdio>
struct T { int id; static int live; T() : id(++live) { printf("ctor %d\n", id); } ~T() { printf("dtor %d\n", id); --live; } };
int T::live = 0;
void f() {
  T grid[2][2];
  printf("in f %d\n", T::live);
}
void g() {
  static T once[2];
  printf("in g %d\n", T::live);
}
struct N { int a; N(int x) : a(x) { printf("N %d\n", a); } N() : a(0) { printf("N0\n"); } ~N() { printf("~N %d\n", a); } };
void k() { static N ns[2] = {N(1), N(2)}; printf("k %d\n", ns[1].a); }
void m() { N grid[2][2] = {{N(1), N(2)}, {N(3), N(4)}}; printf("m %d\n", grid[1][0].a); }
void p() { N part[3] = {N(7)}; printf("p %d %d\n", part[0].a, part[2].a); }
void q() { N g3[2][2][2]; printf("q\n"); }
int main() { f(); g(); g(); k(); k(); m(); p(); q(); printf("end %d\n", T::live); return 0; }

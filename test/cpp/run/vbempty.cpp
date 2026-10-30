// vbempty.cpp: an empty virtual base the class holds is placed as the ABI places it -- offset 0, or past the data where an
// empty subobject of its type lies there already -- and a pointer converts to it through the table (0.235; the Itanium ABI
// 2.4 II.3 and III). Shapes of the virtual-base survey, the sizes and offsets clang++ lays.
extern "C" int printf(const char *, ...);
namespace s176 {
struct C0 {  };
struct C1 : virtual C0 {  };
struct C2 : C0, C1 { virtual int f2() { return 1002; } };
int run() {
  C2 *o = new C2;
  printf("size %d\n", (int) sizeof(C2));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  delete o;
  return 0;
}
}
namespace s179 {
struct C0 {  };
struct C1 : virtual C0 { int m1_0 = 101; int m1_1 = 102; virtual int f1() { return 1001; } };
struct C2 : virtual C0 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
struct C3 : C0, virtual C1 {  };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf(" m %d", b->m1_1); b->m1_1 += 7;
    printf(" f %d", b->f1());
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C1.m1 %d\n", static_cast<C1 *>(o)->m1_1);
  delete o;
  return 0;
}
}
namespace s200 {
struct C0 {  };
struct C1 : virtual C0 { int m1_0 = 101; int m1_1 = 102; };
struct C2 : C1, C0 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
int run() {
  C2 *o = new C2;
  printf("size %d\n", (int) sizeof(C2));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf(" m %d", b->m1_1); b->m1_1 += 7;
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C1.m1 %d\n", static_cast<C1 *>(o)->m1_1);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  delete o;
  return 0;
}
}
namespace s374 {
struct C0 {  };
struct C1 : C0 { virtual int f1() { return 1001; } };
struct C2 : C1, C0 { int m2_0 = 201; };
struct C3 : C0, virtual C1, virtual C2 { int m3_0 = 301; };
struct C4 : virtual C0, C1 { int m4_0 = 401; int m4_1 = 402; };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f1());
    printf("\n"); }
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  printf("C4.m1 %d\n", static_cast<C4 *>(o)->m4_1);
  delete o;
  return 0;
}
}
namespace s384 {
struct C0 {  };
struct C1 : C0 {  };
struct C2 : virtual C1, virtual C0 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
struct C3 : virtual C1, virtual C2 { int m3_0 = 301; };
struct C4 : virtual C0, virtual C2, virtual C1 { int m4_0 = 401; int m4_1 = 402; virtual int f4() { return 1004; } };
struct C5 : C4, virtual C0 { virtual int f5() { return 1005; } };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" m %d", b->m2_1); b->m2_1 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m4_0); b->m4_0 += 7;
    printf(" m %d", b->m4_1); b->m4_1 += 7;
    printf(" f %d", b->f4());
    printf("\n"); }
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  printf("C4.m1 %d\n", static_cast<C4 *>(o)->m4_1);
  delete o;
  return 0;
}
}
namespace s48 {
struct C0 {  };
struct C1 : virtual C0 { int m1_0 = 101; int m1_1 = 102; virtual int f1() { return 1001; } };
struct C2 : virtual C1, C0 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
struct C3 : virtual C1 { virtual int f3() { return 1003; } };
struct C4 : C2 {  };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf(" m %d", b->m1_1); b->m1_1 += 7;
    printf(" f %d", b->f1());
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" m %d", b->m2_1); b->m2_1 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C1.m1 %d\n", static_cast<C1 *>(o)->m1_1);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  delete o;
  return 0;
}
}
namespace s59 {
struct C0 {  };
struct C1 : C0 { virtual int f1() { return 1001; } };
struct C2 : C1, virtual C0 { int m2_0 = 201; virtual int f2() { return 1002; } };
struct C3 : C2, virtual C0, C1 { int m3_0 = 301; int m3_1 = 302; };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  printf("C3.m1 %d\n", static_cast<C3 *>(o)->m3_1);
  delete o;
  return 0;
}
}
namespace e5 {
struct C0 {};
struct C1 : virtual C0 { int m1_0 = 101; };
struct C2 : virtual C1 { virtual int f2() { return 1002; } };
struct B { int b = 7; };
struct D : B, C1 { int d = 9; };
int run() {
  C2 *o = new C2;
  C1 *c = o;
  C0 *a = o, *d = c;
  printf("C1 at %d C0 at %d %d\n", (int)((char *)c - (char *)o), (int)((char *)a - (char *)o), (int)((char *)d - (char *)o));
  D *p = new D;
  C1 *pc = p;
  C0 *pa = p, *pd = pc;
  printf("C1 at %d C0 at %d %d\n", (int)((char *)pc - (char *)p), (int)((char *)pa - (char *)p), (int)((char *)pd - (char *)p));
  delete o;
  delete p;
  return 0;
}
}
namespace t1095 {
struct C0 {  };
struct C1 : virtual C0 { int m1_0 = 101; };
struct C2 : C0, C1 { int m2_0 = 201; virtual int f2() { return 1002; } };
struct C3 : virtual C2 { int m3_0 = 301; int m3_1 = 302; };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  printf("C3.m1 %d\n", static_cast<C3 *>(o)->m3_1);
  delete o;
  return 0;
}
}
namespace t1245 {
struct C0 {  };
struct C1 : C0 { int m1_0 = 101; virtual int f1() { return 1001; } };
struct C2 : virtual C1, virtual C0 {  };
struct C3 : C1, C0 { int m3_0 = 301; int m3_1 = 302; };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf(" f %d", b->f1());
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  printf("C3.m1 %d\n", static_cast<C3 *>(o)->m3_1);
  delete o;
  return 0;
}
}
int main() {
  printf("-- s176\n"); s176::run();
  printf("-- s179\n"); s179::run();
  printf("-- s200\n"); s200::run();
  printf("-- s374\n"); s374::run();
  printf("-- s384\n"); s384::run();
  printf("-- s48\n"); s48::run();
  printf("-- s59\n"); s59::run();
  printf("-- e5\n"); e5::run();
  printf("-- t1095\n"); t1095::run();
  printf("-- t1245\n"); t1245::run();
  return 0;
}

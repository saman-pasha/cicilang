// vbtables.cpp: the tables of a class over virtual bases: a later virtual base lends its sub-objects tables at the member
// that holds it, the VTT names a virtual first base and one inside it by their places, a virtual base of the class of a plain
// base gets its own part, and a base variant stores a virtual base's table through its slot (0.235). Shapes of the
// virtual-base survey, the sizes, offsets, members and calls clang++ gives.
extern "C" int printf(const char *, ...);
namespace s87 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : C0 { int m1_0 = 101; int m1_1 = 102; virtual int f1() { return 1001; } };
struct C2 : C0, C1 { int m2_0 = 201; virtual int f2() { return 1002; } };
struct C3 : virtual C2, C1 {  };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  delete o;
  return 0;
}
}
namespace s274 {
struct C0 { int m0_0 = 1; virtual int f0() { return 1000; } };
struct C1 : virtual C0 { virtual int f1() { return 1001; } };
struct C2 : C1, C0 { virtual int f2() { return 1002; } };
struct C3 : virtual C0, virtual C2 { int m3_0 = 301; };
int run() {
  C3 *o = new C3;
  printf("size %d\n", (int) sizeof(C3));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f1());
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f2());
    printf("\n"); }
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  delete o;
  return 0;
}
}
namespace s75 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : virtual C0 { int m1_0 = 101; int m1_1 = 102; };
struct C2 : virtual C0, C1 {  };
struct C3 : C0, virtual C2 { int m3_0 = 301; virtual int f3() { return 1003; } };
struct C4 : virtual C1, C0, virtual C2 { int m4_0 = 401; int m4_1 = 402; virtual int f4() { return 1004; } };
struct C5 : virtual C1, virtual C4 { virtual int f5() { return 1005; } };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m4_0); b->m4_0 += 7;
    printf(" m %d", b->m4_1); b->m4_1 += 7;
    printf(" f %d", b->f4());
    printf("\n"); }
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  printf("C4.m1 %d\n", static_cast<C4 *>(o)->m4_1);
  delete o;
  return 0;
}
}
namespace s170 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : virtual C0 { int m1_0 = 101; virtual int f1() { return 1001; } };
struct C2 : C1 { virtual int f2() { return 1002; } };
struct C3 : virtual C0, virtual C2, virtual C1 {  };
struct C4 : C3, C1 { int m4_0 = 401; virtual int f4() { return 1004; } };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C0 *b = o; printf("C0 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m0_0); b->m0_0 += 7;
    printf(" m %d", b->m0_1); b->m0_1 += 7;
    printf(" f %d", b->f0());
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f2());
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  printf("C0.m0 %d\n", static_cast<C0 *>(o)->m0_0);
  printf("C0.m1 %d\n", static_cast<C0 *>(o)->m0_1);
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  delete o;
  return 0;
}
}
namespace t2297 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : virtual C0 { int m1_0 = 101; int m1_1 = 102; virtual int f1() { return 1001; } };
struct C2 : C0, C1 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
struct C3 : virtual C2, virtual C0 {  };
struct C4 : virtual C1, virtual C2, C0 { virtual int f4() { return 1004; } };
struct C5 : C4, C2, C1 { int m5_0 = 501; int m5_1 = 502; };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f4());
    printf("\n"); }
  printf("C5.m0 %d\n", static_cast<C5 *>(o)->m5_0);
  printf("C5.m1 %d\n", static_cast<C5 *>(o)->m5_1);
  delete o;
  return 0;
}
}
namespace t2210 {
struct C0 { virtual int f0() { return 1000; } };
struct C1 : virtual C0 {  };
struct C2 : virtual C1, virtual C0 { virtual int f2() { return 1002; } };
struct C3 : virtual C2, C0 {  };
struct C4 : C2 { virtual int f4() { return 1004; } };
struct C5 : virtual C1 {  };
struct C6 : virtual C0, C2, C4 { int m6_0 = 601; };
struct C7 : C3, virtual C6, virtual C2 { int m7_0 = 701; int m7_1 = 702; virtual int f7() { return 1007; } };
int run() {
  C7 *o = new C7;
  printf("size %d\n", (int) sizeof(C7));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f4());
    printf("\n"); }
  { C6 *b = o; printf("C6 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m6_0); b->m6_0 += 7;
    printf("\n"); }
  printf("C6.m0 %d\n", static_cast<C6 *>(o)->m6_0);
  printf("C7.m0 %d\n", static_cast<C7 *>(o)->m7_0);
  printf("C7.m1 %d\n", static_cast<C7 *>(o)->m7_1);
  delete o;
  return 0;
}
}
namespace t1162 {
struct C0 {  };
struct C1 : virtual C0 { virtual int f1() { return 1001; } };
struct C2 : C1, C0 { virtual int f2() { return 1002; } };
struct C3 : virtual C1, virtual C2 { int m3_0 = 301; int m3_1 = 302; };
struct C4 : virtual C0, C2 { virtual int f4() { return 1004; } };
struct C5 : virtual C4 { int m5_0 = 501; };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f1());
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f2());
    printf("\n"); }
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f4());
    printf("\n"); }
  printf("C5.m0 %d\n", static_cast<C5 *>(o)->m5_0);
  delete o;
  return 0;
}
}
namespace t2077 {
struct C0 { int m0_0 = 1; };
struct C1 : C0 { int m1_0 = 101; };
struct C2 : virtual C0 {  };
struct C3 : virtual C0, C2 {  };
struct C4 : virtual C3, virtual C1 { int m4_0 = 401; int m4_1 = 402; virtual int f4() { return 1004; } };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m1_0); b->m1_0 += 7;
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  printf("C1.m0 %d\n", static_cast<C1 *>(o)->m1_0);
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  printf("C4.m1 %d\n", static_cast<C4 *>(o)->m4_1);
  delete o;
  return 0;
}
}
int main() {
  printf("-- s87\n"); s87::run();
  printf("-- s274\n"); s274::run();
  printf("-- s75\n"); s75::run();
  printf("-- s170\n"); s170::run();
  printf("-- t2297\n"); t2297::run();
  printf("-- t2210\n"); t2210::run();
  printf("-- t1162\n"); t1162::run();
  printf("-- t2077\n"); t2077::run();
  return 0;
}

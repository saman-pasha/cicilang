// vbtailpad.cpp: a virtual base takes the tail padding of the one before it, and a base-variant form keeps its alignment
// (0.235; the Itanium ABI 2.4 II and III). Shapes of the virtual-base survey, the sizes and offsets clang++ lays.
extern "C" int printf(const char *, ...);
namespace s13 {
struct C0 { int m0_0 = 1; };
struct C1 : C0 {  };
struct C2 : C1 { virtual int f2() { return 1002; } };
struct C3 : virtual C2, virtual C1, C0 {  };
struct C4 : C3 {  };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" f %d", b->f2());
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  delete o;
  return 0;
}
}
namespace s301 {
struct C0 { int m0_0 = 1; int m0_1 = 2; };
struct C1 : virtual C0 { int m1_0 = 101; };
struct C2 : virtual C0, C1 { int m2_0 = 201; int m2_1 = 202; };
struct C3 : virtual C0 { int m3_0 = 301; int m3_1 = 302; };
struct C4 : C0 {  };
struct C5 : virtual C2, C1 {  };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C0 *b = o; printf("C0 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m0_0); b->m0_0 += 7;
    printf(" m %d", b->m0_1); b->m0_1 += 7;
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" m %d", b->m2_1); b->m2_1 += 7;
    printf("\n"); }
  printf("C0.m0 %d\n", static_cast<C0 *>(o)->m0_0);
  printf("C0.m1 %d\n", static_cast<C0 *>(o)->m0_1);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  delete o;
  return 0;
}
}
namespace s347 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : C0 { int m1_0 = 101; virtual int f1() { return 1001; } };
struct C2 : virtual C0 { int m2_0 = 201; virtual int f2() { return 1002; } };
struct C3 : C2 { int m3_0 = 301; virtual int f3() { return 1003; } };
struct C4 : C2, C3, C0 { int m4_0 = 401; };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m3_0); b->m3_0 += 7;
    printf(" f %d", b->f3());
    printf("\n"); }
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  delete o;
  return 0;
}
}
namespace s133 {
struct C0 { int m0_0 = 1; virtual int f0() { return 1000; } };
struct C1 : C0 { int m1_0 = 101; };
struct C2 : C1, C0 { int m2_0 = 201; int m2_1 = 202; };
struct C3 : virtual C1, virtual C2 { virtual int f3() { return 1003; } };
struct C4 : C3 { int m4_0 = 401; int m4_1 = 402; };
struct C5 : C3, virtual C4 { int m5_0 = 501; virtual int f5() { return 1005; } };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" m %d", b->m2_1); b->m2_1 += 7;
    printf("\n"); }
  { C4 *b = o; printf("C4 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m4_0); b->m4_0 += 7;
    printf(" m %d", b->m4_1); b->m4_1 += 7;
    printf("\n"); }
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  printf("C4.m0 %d\n", static_cast<C4 *>(o)->m4_0);
  printf("C4.m1 %d\n", static_cast<C4 *>(o)->m4_1);
  printf("C5.m0 %d\n", static_cast<C5 *>(o)->m5_0);
  delete o;
  return 0;
}
}
namespace s186 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : virtual C0 { int m1_0 = 101; };
struct C2 : C1, virtual C0 { int m2_0 = 201; };
struct C3 : virtual C2, virtual C0 { int m3_0 = 301; virtual int f3() { return 1003; } };
struct C4 : C3, virtual C1, virtual C2 {  };
int run() {
  C4 *o = new C4;
  printf("size %d\n", (int) sizeof(C4));
  { C0 *b = o; printf("C0 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m0_0); b->m0_0 += 7;
    printf(" m %d", b->m0_1); b->m0_1 += 7;
    printf(" f %d", b->f0());
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m3_0); b->m3_0 += 7;
    printf(" f %d", b->f3());
    printf("\n"); }
  printf("C0.m0 %d\n", static_cast<C0 *>(o)->m0_0);
  printf("C0.m1 %d\n", static_cast<C0 *>(o)->m0_1);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  delete o;
  return 0;
}
}
namespace s227 {
struct C0 { int m0_0 = 1; int m0_1 = 2; virtual int f0() { return 1000; } };
struct C1 : virtual C0 {  };
struct C2 : C1, virtual C0 { int m2_0 = 201; int m2_1 = 202; virtual int f2() { return 1002; } };
struct C3 : virtual C2 { int m3_0 = 301; virtual int f3() { return 1003; } };
struct C4 : virtual C2, virtual C0 { virtual int f4() { return 1004; } };
struct C5 : C3 { int m5_0 = 501; int m5_1 = 502; virtual int f5() { return 1005; } };
int run() {
  C5 *o = new C5;
  printf("size %d\n", (int) sizeof(C5));
  { C0 *b = o; printf("C0 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m0_0); b->m0_0 += 7;
    printf(" m %d", b->m0_1); b->m0_1 += 7;
    printf(" f %d", b->f0());
    printf("\n"); }
  { C1 *b = o; printf("C1 at %d", (int) ((char *) b - (char *) o));
    printf("\n"); }
  { C2 *b = o; printf("C2 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m2_0); b->m2_0 += 7;
    printf(" m %d", b->m2_1); b->m2_1 += 7;
    printf(" f %d", b->f2());
    printf("\n"); }
  { C3 *b = o; printf("C3 at %d", (int) ((char *) b - (char *) o));
    printf(" m %d", b->m3_0); b->m3_0 += 7;
    printf(" f %d", b->f3());
    printf("\n"); }
  printf("C0.m0 %d\n", static_cast<C0 *>(o)->m0_0);
  printf("C0.m1 %d\n", static_cast<C0 *>(o)->m0_1);
  printf("C2.m0 %d\n", static_cast<C2 *>(o)->m2_0);
  printf("C2.m1 %d\n", static_cast<C2 *>(o)->m2_1);
  printf("C3.m0 %d\n", static_cast<C3 *>(o)->m3_0);
  printf("C5.m0 %d\n", static_cast<C5 *>(o)->m5_0);
  printf("C5.m1 %d\n", static_cast<C5 *>(o)->m5_1);
  delete o;
  return 0;
}
}
int main() {
  printf("-- s13\n"); s13::run();
  printf("-- s301\n"); s301::run();
  printf("-- s347\n"); s347::run();
  printf("-- s133\n"); s133::run();
  printf("-- s186\n"); s186::run();
  printf("-- s227\n"); s227::run();
  return 0;
}

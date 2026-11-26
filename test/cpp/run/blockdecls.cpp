// what a block declares (1.6.22): a function's declaration hides the name's outer overloads to the block's end
// ([basic.lookup]/1, [over.dcl]) -- named by its parameters as a call sees them, a top-level const off and an array a
// pointer -- and a local class defined in its object's declaration has its members. Until 1.6.22
// `{ void ov(int); ov(2.5); }' called ov(double), and `o.m(1)' over `struct S2 { ... } o;' was refused `no_member'
#include <cstdio>
void ov(int x) { std::printf("ov(int) %d\n", x); }
void ov(double x) { std::printf("ov(double) %g\n", x); }
int tw(int x) { return 2 * x; }
void q(int x) { std::printf("q(int) %d\n", x); }
void q(double x) { std::printf("q(double) %g\n", x); }
void ar(int *a) { std::printf("ar(int *) %d\n", a[1]); }
void ar(long n) { std::printf("ar(long) %ld\n", n); }
int main() {
  {
    void ov(int);
    ov(2.5);
    { ov(3.5); }
  }
  ov(2.5);
  {
    void q(const int);
    void ar(int a[]);
    int v[2] = {5, 6};
    q(2.5);
    ar(v);
  }
  q(2.5);
  {
    void ov(double);
    ov(4);
  }
  struct S2 { int k; int m(int v) { return v + k; } } o{10}, p{20};
  struct S3 { int twice(int v) const { return tw(v); } } const t{};
  std::printf("%d %d %d\n", o.m(1), p.m(2), t.twice(3));
  return 0;
}

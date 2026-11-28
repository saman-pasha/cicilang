// A SCALAR FOR A MEMBER'S NON-CONST REFERENCE TO A CLASS, TWO MEMBERS OF THE NAME (1.6.56)
struct S { int k; };
struct T { void m(S &s) { s.k = 1; } void m(S &s, int) { } };
int main() {
  T t;
  int x = 0;
  t.m(x);
  return x;
}

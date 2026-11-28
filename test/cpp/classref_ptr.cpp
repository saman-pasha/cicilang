// A POINTER'S LVALUE FOR A NON-CONST REFERENCE TO A CLASS (1.6.56)
struct S { int k; };
int f(S &s) { return s.k; }
int main() {
  int *p = 0;
  return f(p);
}

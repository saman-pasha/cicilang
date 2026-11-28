// A SCALAR'S LVALUE FOR A NON-CONST REFERENCE TO A CLASS (1.6.56): `f(x)' over an int built and wrote the int's bytes as an S
struct S { int k; };
void f(S &s) { s.k = 1; }
int main() {
  int x = 0;
  f(x);
  return x;
}

// AN ENUMERATION'S LVALUE FOR A NON-CONST REFERENCE TO A CLASS (1.6.56)
struct S { int k; };
enum E { A, B };
int f(S &s) { return s.k; }
int main() {
  E e = B;
  return f(e);
}

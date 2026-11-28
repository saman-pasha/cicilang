// A TEMPLATE'S NON-CONST REFERENCE TO A CLASS GIVEN AN INTEGER (1.6.56): it built, the reference bound to a temporary
struct S { int k; };
template <class T> int f(T a, S &s) { return a + s.k; }
int main() {
  return f(1, 2);
}

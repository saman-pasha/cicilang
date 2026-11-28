// A CLASS BY VALUE AND BY CONST REFERENCE, A DERIVED CLASS'S OBJECT GIVEN (1.6.56)
struct S { int k; };
struct D : S { };
int f(S s) { return 1; }
int f(const S &s) { return 2; }
int main() {
  D d;
  return f(d);
}

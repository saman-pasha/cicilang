// A SCALAR FOR A VOLATILE REFERENCE TO A CLASS WITH A CONVERTING CONSTRUCTOR (1.6.56): the temporary binds no volatile reference
struct S { int k; S(int j) : k(j) {} };
int f(volatile S &s) { return 1; }
int main() {
  int x = 7;
  return f(x);
}

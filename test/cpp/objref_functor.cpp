// A CLASS'S operator() WHOSE NON-CONST REFERENCE IS GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct F { void operator()(int &x) const { x = 1; } };
int main() {
  F f;
  long a = 0;
  f(a);
  return 0;
}

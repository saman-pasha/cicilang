// A TEMPORARY OF A CLASS WITH A CONSTRUCTOR, CALLED, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct F { int k; F() : k(1) {} void operator()(int &x) const { x = k; } };
int main() {
  long a = 0;
  F()(a);
  return 0;
}

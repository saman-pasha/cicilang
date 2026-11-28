// AN OBJECT'S operator() THROUGH A SUBSCRIPT, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct H { void operator()(int &x) const { x = 1; } };
int main() {
  H hs[2];
  long a = 0;
  hs[0](a);
  return 0;
}

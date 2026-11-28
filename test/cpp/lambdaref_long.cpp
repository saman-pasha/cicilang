// A LAMBDA'S NON-CONST REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56): `l(a)' over a long built and wrote the int's bytes
int main() {
  auto l = [](int &x) { x = 1; };
  long a = 0;
  l(a);
  return (int)a;
}

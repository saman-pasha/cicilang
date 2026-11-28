// A LAMBDA'S NON-CONST REFERENCE GIVEN A CONST LVALUE (1.6.56)
int main() {
  auto l = [](int &x) { x = 1; };
  const int c = 0;
  l(c);
  return 0;
}

// A LAMBDA'S NON-CONST REFERENCE GIVEN A LITERAL (1.6.56)
int main() {
  auto l = [](int &x) { x = 1; };
  l(3);
  return 0;
}

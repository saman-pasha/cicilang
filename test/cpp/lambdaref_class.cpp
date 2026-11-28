// A LAMBDA'S NON-CONST REFERENCE TO A CLASS GIVEN A SCALAR (1.6.56)
struct S { int k; };
int main() {
  auto l = [](S &s) { s.k = 1; };
  int x = 0;
  l(x);
  return 0;
}

// A VALUE AND A CONST REFERENCE OF ONE TYPE, BOTH A CONVERSION (1.6.56): `f(i)' took the first declared
int f(long x) { return 1; }
int f(const long &x) { return 2; }
int main() {
  int i = 3;
  return f(i);
}

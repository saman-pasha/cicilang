// AN OVERLOAD OF DEFAULT ARGUMENTS BESIDE AN EXACT REFERENCE (1.6.56): `f(a)' took the reference
int f(int x, int y = 0) { return x + y; }
int f(int &x) { return x + 1; }
int main() {
  int a = 3;
  return f(a);
}

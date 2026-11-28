// ... BOUND TO A CONST REFERENCE PARAMETER (1.6.56)
struct X { int k; ~X() = delete; };
X f();
int h(const X &x) { return x.k; }
int main() {
  return h(f());
}

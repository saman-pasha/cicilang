// ... GIVEN TO A PARAMETER BY VALUE (1.6.56)
struct X { int k; ~X() = delete; };
X f();
int g(X x) { return x.k; }
int main() {
  return g(f());
}

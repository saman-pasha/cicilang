// ... CAST TO VOID (1.6.56)
struct X { int k; ~X() = delete; };
X f();
int main() {
  (void)f();
  return 0;
}

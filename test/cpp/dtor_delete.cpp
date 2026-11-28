// ... A DELETE (1.6.55)
struct X { ~X() = delete; };
void f(X *p) {
  delete p;
}
int main() {
  return 0;
}

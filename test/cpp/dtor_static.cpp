// ... A STATIC LOCAL (1.6.55)
struct X { ~X() = delete; };
int main() {
  static X s;
  return 0;
}

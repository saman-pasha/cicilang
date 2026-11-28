// ... AND ONE WHOSE ONE CONSTRUCTOR, DELETED, TAKES AN ARGUMENT (1.6.55): it declares a constructor, so no default one is made; it built
struct X { X(int) = delete; };
int main() {
  X x;
  return 0;
}

// ... A TEMPORARY, destroyed at its full-expression's end (1.6.55)
struct X { ~X() = delete; };
int main() {
  X();
  return 0;
}

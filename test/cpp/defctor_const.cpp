// ... A CONST ONE, by its type as clang++ names it (1.6.55)
struct X { X() = delete; };
int main() {
  const X x;
  return 0;
}

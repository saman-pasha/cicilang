// A DELETED MEMBER FUNCTION, THE ONE DECLARATION OF ITS NAME (1.6.55): clang++ names it alone, no overload resolved
struct X { void g() = delete; };
int main() {
  X x;
  x.g();
  return 0;
}

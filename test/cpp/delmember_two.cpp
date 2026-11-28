// TWO DELETED MEMBERS OF ONE NAME, no live one (1.6.55): overload resolution, so clang++ names the member
struct X { void g(int) = delete; void g(double) = delete; };
int main() {
  X x;
  x.g(1);
  return 0;
}

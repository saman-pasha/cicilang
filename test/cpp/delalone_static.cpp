// ... A STATIC ONE (1.6.55)
struct X { static void g() = delete; };
int main() {
  X::g();
  return 0;
}

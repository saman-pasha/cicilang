// ... A BASE WHOSE DEFAULT CONSTRUCTOR IS DELETED (1.6.55)
struct B { B() = delete; };
struct D : B {};
int main() {
  D d;
  return 0;
}

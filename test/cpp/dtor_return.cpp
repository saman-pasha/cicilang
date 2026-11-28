// ... A RETURNED ONE, which its caller destroys (1.6.55)
struct X { ~X() = delete; };
X f() {
  return X();
}
int main() {
  return 0;
}

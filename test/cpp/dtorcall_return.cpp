// ... RETURNED BY ITS CALLER, AND A MEMBER READ OF IT (1.6.56): clang++ binds the call's result to a temporary first
struct X { int k; ~X() = delete; };
X f();
X e() {
  return f();
}
int main() { return 0; }

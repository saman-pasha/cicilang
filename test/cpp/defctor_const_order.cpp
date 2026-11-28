// A CONST OBJECT WHOSE DEFAULT CONSTRUCTOR IS DELETED, OF A CLASS THAT IS NOT CONST-DEFAULT-CONSTRUCTIBLE TOO (1.6.55): the
// constructor's words first, as clang++ asks them, 1.6.50's after
struct X { X() = delete; int k; };
int main() {
  const X x;
  return 0;
}

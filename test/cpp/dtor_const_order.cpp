// A CONST OBJECT WHOSE DESTRUCTOR IS DELETED, OF A CLASS THAT IS NOT CONST-DEFAULT-CONSTRUCTIBLE (1.6.55): 1.6.50's words first,
// the destructor's after, as clang++ asks them
struct X { ~X() = delete; int k; };
int main() {
  const X x;
  return 0;
}

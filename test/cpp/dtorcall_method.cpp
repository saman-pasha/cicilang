// A MEMBER FUNCTION'S RESULT OF A CLASS WHOSE DESTRUCTOR IS DELETED, THROWN AWAY (1.6.56)
struct X { int k; ~X() = delete; };
struct M { X make(); };
int main() {
  M m;
  m.make();
  return 0;
}

// A CALL'S RESULT OF A CLASS WHOSE DESTRUCTOR IS DELETED, THROWN AWAY (1.6.56): it built
struct X { int k; ~X() = delete; };
X f();
int main() {
  f();
  return 0;
}

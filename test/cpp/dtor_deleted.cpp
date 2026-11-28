// AN OBJECT WHOSE DESTRUCTOR IS DELETED (1.6.55): the record drops `~X() = delete', and the object was destroyed as one with nothing to destroy
struct X { ~X() = delete; };
int main() {
  X x;
  return 0;
}

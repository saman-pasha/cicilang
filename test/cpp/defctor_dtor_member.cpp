// ... A MEMBER WHOSE DESTRUCTOR IS DELETED (1.6.55; [class.default.ctor]/2.7)
struct X { ~X() = delete; };
struct Y { X x; };
int main() {
  Y y;
  return 0;
}

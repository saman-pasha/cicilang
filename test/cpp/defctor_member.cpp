// AN IMPLICIT DEFAULT CONSTRUCTOR THAT A MEMBER DELETES (1.6.55; [class.default.ctor]/2): the member's `X() = delete'
struct X { X() = delete; };
struct Y { X x; };
int main() {
  Y y;
  return 0;
}

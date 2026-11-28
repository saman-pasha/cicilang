// A DESTRUCTOR THAT A MEMBER DELETES (1.6.55; [class.dtor]/7): the implicit destructor of Y, whose x's destructor is deleted, at a delete
struct X { ~X() = delete; };
struct Y { X x; };
void f(Y *p) {
  delete p;
}
int main() {
  return 0;
}

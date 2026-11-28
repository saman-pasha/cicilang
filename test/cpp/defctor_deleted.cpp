// AN OBJECT OF A CLASS WHOSE DEFAULT CONSTRUCTOR IS DELETED (1.6.55): `X x;' over `X() = delete' built, the record holding no constructor
struct X { X() = delete; };
int main() {
  X x;
  return 0;
}

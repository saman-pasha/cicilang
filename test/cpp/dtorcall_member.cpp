// A CALL'S RESULT WHOSE DESTRUCTOR A MEMBER DELETES, THROWN AWAY (1.6.56)
struct Y { ~Y() = delete; };
struct X { int k; Y y; };
X f();
int main() {
  f();
  return 0;
}

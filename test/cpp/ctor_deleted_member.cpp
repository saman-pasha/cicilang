// A USER-PROVIDED CONSTRUCTOR THAT LEAVES A MEMBER WHOSE DEFAULT CONSTRUCTOR IS DELETED (1.6.55; [class.base.init]/9): at the constructor's line
struct X { X() = delete; };
struct Y {
  int k; X x;
  Y(int a) : k(a) {}
};
int main() {
  return 0;
}

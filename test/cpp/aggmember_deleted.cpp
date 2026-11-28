// AN AGGREGATE'S MEMBER WITH NO ITEM, WHOSE CLASS'S DEFAULT CONSTRUCTOR IS DELETED (1.6.56)
struct X { X() = delete; X(int) {} };
struct Z { int a; X x; };
int main() {
  Z z = {1};
  (void)z;
  return 0;
}

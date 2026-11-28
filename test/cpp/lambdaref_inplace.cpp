// A LAMBDA CALLED WHERE IT IS MADE, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56): the column is the introducer's
int main() {
  long a = 0;
  [](int &x) { x = 1; }(a);
  return 0;
}

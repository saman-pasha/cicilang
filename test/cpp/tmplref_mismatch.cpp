// A TEMPLATE'S REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56): it was `not lowered yet: argument_mismatch'
template <class T> void f(T &, int &) {}
int main() {
  long a = 0;
  f(a, a);
  return 0;
}

// A TEMPLATE CALLED WITH ITS ARGUMENTS GIVEN, ITS REFERENCE AN LVALUE OF ANOTHER TYPE (1.6.56)
template <class T> void f(T &, int &) {}
int main() {
  long a = 0;
  f<long>(a, a);
  return 0;
}

// A TEMPLATE'S DEDUCED REFERENCE GIVEN A LITERAL (1.6.56)
template <class T> int f(T &x) { return x; }
int main() {
  return f(3);
}

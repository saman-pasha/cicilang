// A CLASS WHOSE ONE CONSTRUCTOR IS A TEMPLATE THAT TAKES AN ARGUMENT (1.6.55): it declares a constructor, and none takes no argument;
// it was `not lowered yet: no_constructor('T',0)'
struct T { template <class U> T(U) {} };
int main() {
  T t;
  return 0;
}

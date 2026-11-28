// A NAMESPACE'S TEMPLATE, QUALIFIED, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
namespace N { template <class T> void f(T &, int &) {} }
int main() {
  long a = 0;
  N::f(a, a);
  return 0;
}

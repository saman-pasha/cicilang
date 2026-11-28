// A NAMESPACE'S OBJECT'S operator(), QUALIFIED, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct H { void operator()(int &x) const { x = 1; } };
namespace N { H hn; }
int main() {
  long a = 0;
  N::hn(a);
  return 0;
}

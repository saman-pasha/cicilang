// A DATA MEMBER'S operator() CALLED THROUGH AN OBJECT AND A POINTER, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct H { void operator()(int &x) const { x = 1; } };
struct K { H h; };
int main() {
  K k;
  long a = 0;
  k.h(a);
  return 0;
}

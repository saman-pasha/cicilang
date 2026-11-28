// A DATA MEMBER'S operator() CALLED BARE IN A MEMBER FUNCTION, ITS REFERENCE GIVEN AN LVALUE OF ANOTHER TYPE (1.6.56)
struct H { void operator()(int &x) const { x = 1; } };
struct K { H h; void run() { long a = 0; h(a); } };
int main() {
  K k;
  k.run();
  return 0;
}

// ... A REFERENCE MEMBER WITH NO INITIALIZER (1.6.55)
struct R { int &r; };
int main() {
  R r;
  return 0;
}

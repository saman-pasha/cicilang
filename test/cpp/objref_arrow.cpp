// ... THROUGH A POINTER (1.6.56)
struct H { void operator()(int &x) const { x = 1; } };
struct K { H h; };
int main() {
  K k;
  K *p = &k;
  long a = 0;
  p->h(a);
  return 0;
}

// THE SECOND LAMBDA OF A LINE (1.6.56): its place is the second introducer's
int main() {
  auto k = [](long) {}; auto l = [](int &x) { x = 1; };
  long a = 0;
  l(a);
  k(a);
  return 0;
}

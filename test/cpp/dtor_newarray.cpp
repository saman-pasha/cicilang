// ... AN ARRAY'S NEW, whose elements are destroyed where a later one's construction throws (1.6.55)
struct X { ~X() = delete; };
int main() {
  X *p = new X[2];
  (void)p;
  return 0;
}

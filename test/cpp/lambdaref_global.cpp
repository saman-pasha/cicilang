// A LAMBDA AT FILE SCOPE AFTER A FUNCTION (1.6.56): its place is its declaration's line, not the last statement's
int k() { return 0; }
auto g = [](int &x) { x = 1; };
int main() {
  long a = 0;
  g(a);
  return k();
}

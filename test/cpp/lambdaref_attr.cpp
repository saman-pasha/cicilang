// A LAMBDA AFTER AN ATTRIBUTE ON ITS LINE (1.6.56): an attribute's `[[' is no introducer
int main() {
  long a = 0;
  [[maybe_unused]] int u = 0; auto l = [](int &x) { x = 1; };
  l(a);
  return 0;
}

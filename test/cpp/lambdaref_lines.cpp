// A LAMBDA ON THE LINE AFTER ITS DECLARATION'S FIRST (1.6.56): its place is its introducer's line and column
int main() {
  long a = 0;
  auto l =
    [](int &x) { x = 1; };
  l(a);
  return 0;
}

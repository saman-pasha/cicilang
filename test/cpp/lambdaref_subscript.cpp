// A LAMBDA ON A LINE WITH A SUBSCRIPT BEFORE IT (1.6.56): a `[' after a name is no introducer
int main() {
  long v[2] = {0, 1}; auto l = [](int &x) { x = 1; };
  l(v[0]);
  return 0;
}

// `new X[n]', its bound no constant (1.6.55): `X[]'
struct X { X() = delete; };
int main(int c, char **) {
  X *p = new X[c];
  delete[] p;
  return 0;
}

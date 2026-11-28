// `new Y' OF A CLASS WITH NO DEFAULT CONSTRUCTOR (1.6.55): `not lowered yet: no_constructor('Y',0)'
struct Y { Y(int) {} };
int main() {
  Y *p = new Y;
  delete p;
  return 0;
}

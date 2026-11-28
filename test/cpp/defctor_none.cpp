// A CLASS WHOSE CONSTRUCTORS ALL TAKE ARGUMENTS (1.6.55): `not lowered yet: no_constructor('Y',0)'
struct Y { Y(int) {} };
int main() {
  Y y;
  return 0;
}

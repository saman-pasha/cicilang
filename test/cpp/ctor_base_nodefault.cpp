// ... A BASE WITH NO DEFAULT CONSTRUCTOR (1.6.55): `not lowered yet: base_constructor('Z')'
struct Z { Z(int) {} };
struct W : Z {
  W() {}
};
int main() {
  return 0;
}

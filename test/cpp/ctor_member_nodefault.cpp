// ... A MEMBER WITH NO DEFAULT CONSTRUCTOR (1.6.55)
struct Z { Z(int) {} };
struct V {
  Z z;
  V() {}
};
int main() {
  return 0;
}

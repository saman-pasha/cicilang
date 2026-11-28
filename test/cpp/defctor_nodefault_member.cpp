// ... A MEMBER OF A CLASS WITH NO DEFAULT CONSTRUCTOR (1.6.55)
struct Y { Y(int) {} };
struct Z { Y y; };
int main() {
  Z z;
  return 0;
}

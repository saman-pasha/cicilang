// AN AGGREGATE'S MEMBER WITH NO ITEM, WHOSE CLASS'S CONSTRUCTORS ALL TAKE ARGUMENTS (1.6.56): its bytes
struct Y { Y(int) {} };
struct Z { Y y; };
int main() {
  Z z{};
  (void)z;
  return 0;
}

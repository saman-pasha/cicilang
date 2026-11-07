struct A { int x, y; };
const A a = {1, 2};
static_assert(a.x == 1);
int main() { return a.y; }

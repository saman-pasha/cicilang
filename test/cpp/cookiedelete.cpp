struct T { int v; constexpr T() : v(1) {} constexpr ~T() {} };
constexpr int leak() { T *p = new T[2]; int r = p[0].v; delete p; return r; }
static_assert(leak() == 1);
int main() { return 0; }

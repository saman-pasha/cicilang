struct S { int v; S(int k) : v(k) {} };
constexpr int f() { S s(3); return s.v; }
static_assert(f() == 3);
int main() { return f(); }

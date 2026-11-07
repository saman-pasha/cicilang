struct S { int v = 2; int get() const { return v; } };
constexpr int h() { S s; return s.get(); }
static_assert(h() == 2);
int main() { return h(); }

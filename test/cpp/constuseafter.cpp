// A READ THROUGH A FREED BLOCK IN A CONSTANT EVALUATION IS NO CONSTANT EXPRESSION (0.257; [basic.life]): refused, in clang's words
constexpr int after(bool b) { int *p = new int(4); int *q = new int(5); delete p; int r = b ? *p : *q; delete q; return r; }
static_assert(after(true) == 4);
int main() { return after(false) - 5; }

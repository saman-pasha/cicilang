// A BLOCK FREED TWICE IN A CONSTANT EVALUATION IS NO CONSTANT EXPRESSION (0.257; [expr.delete]/2): refused, in clang's words
constexpr int twice(bool b) { int *p = new int(1); delete p; if (b) delete p; return 1; }
static_assert(twice(true) == 1);
int main() { return twice(false) - 1; }

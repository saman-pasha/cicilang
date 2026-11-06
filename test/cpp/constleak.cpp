// A BLOCK A CONSTANT EVALUATION STILL HOLDS WHERE IT ENDS IS NO CONSTANT EXPRESSION (0.257; [expr.const]/5.19): refused, in clang's words
constexpr int leak() { int *p = new int(1); return *p; }
static_assert(leak() == 1);
int main() { return 0; }

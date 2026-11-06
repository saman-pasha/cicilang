// A STATIC ASSERTION WHOSE CONDITION DOES NOT FOLD IS REFUSED (0.257), in clang's words: a throw caught in constant evaluation (C++26's P3068) is no step the evaluator takes, and the false assertion passed unasked
constexpr int f() { try { throw 40; } catch (int e) { return e + 2; } return 0; }
static_assert(f() == 41);
int main() { return f(); }

// A DELETED STATIC MEMBER FUNCTION, as clang names it, a function (0.257)
struct S { static int f(int) = delete; static int f(long) { return 42; } };
int main() { return S::f(1); }

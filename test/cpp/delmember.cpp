// A DELETED MEMBER FUNCTION THE ARGUMENTS CHOOSE IS REFUSED (0.257): the record dropped it, and s.f(1) called f(long)
struct S { void f(int) = delete; int f(long) { return 42; } };
int main() { S s; return s.f(1); }

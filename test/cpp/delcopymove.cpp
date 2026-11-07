struct M { M() = default; M(M &&) = delete; };
struct S { M m; };
int main() { S a; S b = a; (void)b; }

// A DELETED COPY CONSTRUCTOR (0.257): the class's own lvalue took the implicit memberwise copy
struct S { int v = 42; S() {} S(const S &) = delete; };
int main() { S a; S b = a; return b.v; }

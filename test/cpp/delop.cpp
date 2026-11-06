// A DELETED FREE OPERATOR, with its reason (0.257): it was `not lowered yet: no_operator(==)'
struct S { int v; };
bool operator==(S, S) = delete("compare v");
int main() { S a{1}, b{1}; return a == b ? 42 : 0; }

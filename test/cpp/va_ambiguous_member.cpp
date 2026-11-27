// two members of one key, the ellipsis's and the other's, and a call of as many arguments: clang++'s ambiguity (1.6.38)
struct T { int m(int a) { return a + 10; } int m(int a, ...) { return a + 20; } };
int main() { T t; return t.m(1); }

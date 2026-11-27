// two overloads of one key, the ellipsis's and the other's, and a call of as many arguments: clang++'s ambiguity (1.6.38)
int f(int a) { return a + 1; }
int f(int a, ...) { return a + 100; }
int main() { return f(1); }

// two overloads of one key, the ellipsis's and the other's, and a qualified call of too few arguments: an overload set's
// words, not one function's (1.6.38)
int f(int a) { return a + 1; }
int f(int a, ...) { return a + 100; }
int main() { return ::f(); }

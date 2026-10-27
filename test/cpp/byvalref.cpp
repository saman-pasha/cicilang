// a reference to a parameter by value returned: refused (0.217)
int &f(int n) { return n; }
int main() { return f(3) == 3 ? 0 : 1; }

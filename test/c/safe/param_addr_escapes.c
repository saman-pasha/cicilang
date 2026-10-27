/* the address of a parameter by value returned: refused (0.217) */
int *f(int n) { return &n; }
int main(void) { return f(3) != 0 ? 0 : 1; }

/* the address of a local pointer that borrows a parameter's referent, returned: refused (0.217; it answered what the pointer points to) */
int **f(int *q) { int *p = q; return &p; }
int main(void) { int x = 1; return f(&x) != 0 ? 0 : 1; }

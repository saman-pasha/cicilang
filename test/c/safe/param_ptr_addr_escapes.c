/* the address of a pointer parameter returned: the parameter's own storage, refused (0.219; it answered the referent) */
int **f(int *p) { return &p; }
int main(void) { int x = 1; return f(&x) != 0 ? 0 : 1; }

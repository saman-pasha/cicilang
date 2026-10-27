/* a struct holding a local's address copied into another, which is returned: refused (0.217) */
struct S { int *p; };
struct S mk(void) { int x = 1; struct S s, t; s.p = &x; t = s; return t; }
int main(void) { mk(); return 0; }

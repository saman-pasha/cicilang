/* a struct whose member holds a local's address, returned: refused (0.217) */
struct S { int *p; };
struct S mk(void) { int x = 1; struct S s; s.p = &x; return s; }
int main(void) { mk(); return 0; }

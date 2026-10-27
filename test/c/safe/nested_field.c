/* a nested struct's member given a local's address, the outer struct returned: refused (0.217) */
struct S { int *p; };
struct T { struct S in; int n; };
struct T mk(void) { int x = 1; struct T t; t.n = 0; t.in.p = &x; return t; }
int main(void) { mk(); return 0; }

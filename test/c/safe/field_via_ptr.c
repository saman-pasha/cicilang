/* a store through a local pointer to a local struct, the struct returned: refused (0.217) */
struct S { int *p; };
struct S mk(void) { int x = 1; struct S s; struct S *ps = &s; ps->p = &x; return s; }
int main(void) { mk(); return 0; }

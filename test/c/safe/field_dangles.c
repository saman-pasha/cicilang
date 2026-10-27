/* a member read after the local it held ended: refused (0.217) */
struct S { int *p; };
int main(void) { struct S s; { int x = 1; s.p = &x; } return *s.p; }

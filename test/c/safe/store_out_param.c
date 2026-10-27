/* a local's address stored in the caller's struct through a pointer parameter: refused (0.217) */
struct S { int *p; };
void put(struct S *s) { int x = 1; s->p = &x; }
int main(void) { struct S s; put(&s); return 0; }

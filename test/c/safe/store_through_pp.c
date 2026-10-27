/* a local's address stored in the caller's pointer through a pointer parameter: refused (0.217) */
void put(int **pp) { int x = 1; *pp = &x; }
int main(void) { int *p = 0; put(&p); return p != 0 ? 0 : 1; }

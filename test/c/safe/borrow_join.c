/* a pointer that borrows a parameter on one path and a local on the other leaves the function: the join keeps the local's (0.216) */
int *pick(int c, int *p) { int x = 1; int *q; if (c) q = p; else q = &x; return q; }
int main(void) { int a = 2; return *pick(1, &a) - 2; }

/* a local's address stored in a global: refused (0.217) */
int *g;
void put(void) { int x = 1; g = &x; }
int main(void) { put(); return 0; }

/* an array element read after the local it held ended: refused (0.217) */
int main(void) { int *a[2]; { int x = 1; a[0] = &x; } return *a[0]; }

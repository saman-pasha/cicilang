#include <stdio.h>
struct S { int a; _Static_assert(sizeof(int) == 4, "four"); int b; };
struct T { char c; _Static_assert(sizeof(char) == 1, "one"); };
int main(void) { struct S s = {1, 2}; printf("%d %d %d\n", (int) sizeof(struct S), s.a + s.b, (int) sizeof(struct T)); return 0; }

/* __has_attribute (0.221): 1 for the GNU attributes the compiler recognizes, so a program's layout takes clang's road */
#include <stdio.h>
#if __has_attribute(packed)
struct __attribute__((packed)) P { char c; int i; };
#else
struct P { char c; int i; };
#endif
#if __has_attribute(__aligned__)
struct __attribute__((aligned(16))) A { int i; };
#else
struct A { int i; };
#endif
int main(void) { printf("%d %d %d %d %d\n", (int)sizeof(struct P), (int)_Alignof(struct A), __has_attribute(packed), __has_attribute(__noinline__), __has_attribute(vector_size)); return 0; }

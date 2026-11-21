/* GCC's cleanup attribute refused in clang's words (1.6.8): an array's object, whose address is a pointer to the array */
#include <stdio.h>
static void bye(int *p) { printf("bye %d\n", *p); }
static void byea(int (*p)[2]) { printf("bye %d\n", (*p)[1]); }
int main(void) { int arr[2] __attribute__((cleanup(byea))) = { 1, 2 }; int arr2[2] __attribute__((cleanup(bye))) = { 3, 4 }; printf("%d %d\n", arr[0], arr2[0]); return 0; }

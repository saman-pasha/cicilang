/* An enumerator's value may name another enum's enumerator, of the unit or of a header, and an array's bound such an
   enumerator: the passes folded the unit's enums with their own enumerators alone, and `enum B { Y = X + 1 };' was 0 (0.195) */
#include <stdio.h>
#include <unistd.h>
enum A { X = 5 };
enum B { Y = X + 1, Z = sizeof(int) * X };
enum { SC = _SC_PAGESIZE + 1 };
int main(void) {
    enum C { W = Y * 2 };
    int arr[Y];
    printf("%d %d %d %zu %d\n", Y, Z, W, sizeof arr, SC);
    return 0;
}

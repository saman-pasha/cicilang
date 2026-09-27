#include <stdio.h>
#include <wchar.h>
int main(void) {
    wchar_t a[] = L"hié";
    wchar_t b[6] = L"ab";
    _Alignas(16) int x = 5;
    printf("%d %d %d %d\n", (int) (sizeof(a) / sizeof(a[0])), (int) a[2], (int) b[1], (int) b[5]);
    printf("%d %d\n", x, (int) (((unsigned long) &x) % 16));
    return 0;
}

#include <stdio.h>
int sum(int n, int m) {
    int a[n][m];
    for (int i = 0; i < n; i++) for (int j = 0; j < m; j++) a[i][j] = i * m + j;
    int s = 0;
    for (int i = 0; i < n; i++) for (int j = 0; j < m; j++) s += a[i][j];
    return s + (int) (sizeof(a) / sizeof(int));
}
int main(void) {
    int n = 3;
    int v[n];
    n = 10;
    printf("%d %d\n", sum(3, 4), (int) (sizeof(v) / sizeof(int)));
    return 0;
}

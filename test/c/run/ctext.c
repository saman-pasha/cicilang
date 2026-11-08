#include <stdio.h>
#include <stdlib.h>
#include "ctext.pl"
vec_of(0);
int main(void) {
    vec_int v = { 0, 4, malloc(4 * sizeof(int)) };
    for (int i = 1; i <= 5; i++) vec_int_push(&v, i * i);
    int a = 3, b = 4;
    swap_any(a, b);
    int n = 0;
    repeat2(n++);
    printf("%zu %d %d %d %d %d %d\n", v.len, vec_int_at(&v, 4), a, b, twice(a + 1), quad(b), n);
    free(v.data);
    return 0;
}

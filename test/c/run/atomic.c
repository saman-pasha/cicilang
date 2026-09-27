#include <stdio.h>
#include <stdatomic.h>
_Atomic int counter = 5;
int main(void) {
    _Atomic long total = 100;
    counter++;
    counter += 10;
    ++counter;
    int old = counter--;
    total -= 30;
    total |= 3;
    counter = 40;
    int now = counter;
    atomic_int a = 7;
    atomic_fetch_add(&a, 5);
    int prev = atomic_exchange(&a, 1);
    int e = 1;
    int ok = atomic_compare_exchange_strong(&a, &e, 9);
    printf("%d %d %ld %d %d %d %d\n", old, now, (long) total, prev, ok, atomic_load(&a), e);
    return 0;
}

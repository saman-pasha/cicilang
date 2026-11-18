/* phase 2: a guard's mutex is `mutex', and a type that is none is refused */
#include <mutex.pl>
int main(void) {
    lock_guard<int> g;
    (void)sizeof(g);
    return 0;
}

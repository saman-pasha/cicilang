/* <array.pl>: get<I> of an array checks its index where it is written, as C++'s does, where a[i] is checked when it
   runs (0.305) */
#include <array.pl>
int main(void) {
    array<int, 3> a = [1, 2, 3];
    return get<3>(a);
}

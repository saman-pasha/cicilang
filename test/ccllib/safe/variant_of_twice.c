/* <variant.pl>: a variant of two ints is made of no int, which two alternatives hold, as C++'s converting
   constructor is ambiguous (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, int> v = 5;
    return (int)index(v);
}

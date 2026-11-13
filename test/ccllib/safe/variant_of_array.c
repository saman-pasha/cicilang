/* <variant.pl>: a variant's alternative is no array, as a tuple's element is none (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, int[2]> v;
    return (int)index(v);
}

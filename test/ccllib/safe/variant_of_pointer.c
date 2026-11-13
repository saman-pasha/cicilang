/* <variant.pl>: a variant's alternative is a value with no pointer in it, as an optional's value is (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, char *> v;
    return (int)index(v);
}

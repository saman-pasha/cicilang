/* <variant.pl>: a variant's alternative is no void, as in C++ (0.308) */
#include <variant.pl>
int main(void) {
    variant<void, int> v;
    return (int)index(v);
}

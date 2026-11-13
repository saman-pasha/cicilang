/* <variant.pl>: get<T> of a type that the variant holds twice names no alternative, as in C++ (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, int> v;
    return get<int>(v);
}

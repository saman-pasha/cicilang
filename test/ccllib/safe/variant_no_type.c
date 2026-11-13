/* <variant.pl>: a variant holds one alternative at least, as C++'s does (0.308) */
#include <variant.pl>
int main(void) {
    variant<> v;
    return (int)index(v);
}

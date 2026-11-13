/* <variant.pl>: a variant holds 255 alternatives at most, since its index is a byte: 256 are refused by name, where
   C++ takes any count (0.308) */
#include <variant.pl>
#define I8 int, int, int, int, int, int, int, int
#define I64 I8, I8, I8, I8, I8, I8, I8, I8
int main(void) {
    variant<I64, I64, I64, I64> v;
    return (int)index(v);
}

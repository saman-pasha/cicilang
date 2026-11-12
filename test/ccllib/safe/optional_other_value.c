/* <optional.pl>: a relation with a value takes a value of the optional's own type: `d == 2' over an optional<double>
   is refused by name, where C++ converts 2 (0.300) */
#include <optional.pl>
int main(void) {
    optional<double> d = 2.0;
    return d == 2;
}

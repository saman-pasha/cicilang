/* <optional.pl>: an optional is made of a value of its own type, or of nullopt: an optional<double> made of an
   optional<int> is refused, where C++ converts it (0.300) */
#include <optional.pl>
int main(void) {
    optional<int> i = 2;
    optional<double> d = i;
    return has_value(d) ? 0 : 1;
}

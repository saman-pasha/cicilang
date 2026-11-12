/* <optional.pl>: an optional's value is no nullopt_t, as C++'s is none ([optional.optional.general]/3; 0.300) */
#include <optional.pl>
int main(void) {
    optional<nullopt_t> o;
    return has_value(o);
}

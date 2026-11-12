/* <optional.pl>: an optional's value is no array, as C++'s is none (0.300) */
#include <optional.pl>
typedef int three[3];
int main(void) {
    optional<three> o;
    return has_value(o);
}

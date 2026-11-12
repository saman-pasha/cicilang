/* a typed call by name that the instance has no function for is refused by that function's name (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, double> t = {1, 2.5};
    return get<2>(t);
}

/* <pair.pl>: get<I> of a pair has two indices, 0 and 1 (0.305) */
#include <pair.pl>
int main(void) {
    pair<int, double> p = {1, 2.5};
    return get<2>(p);
}

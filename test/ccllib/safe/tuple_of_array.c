/* <tuple.pl>: a tuple's element is no array, as a pair's member is none (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, int[2]> t;
    return get<0>(t);
}

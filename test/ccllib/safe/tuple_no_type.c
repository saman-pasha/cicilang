/* <tuple.pl>: a tuple takes one type at least: C has no struct of no member, where C++ has tuple<> (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<> t;
    return 0;
}

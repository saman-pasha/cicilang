/* the typed call by name: an index between the < and > is a constant, as C++'s template argument is (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, double> t = {1, 2.5};
    int i = 0;
    return get<i>(t);
}

/* <tuple.pl>: get<I> of an index past the end makes no function, and the reader refuses the typed call by the name
   of the function that the module has not, where C++ fails a static assertion (0.305) */
#include <tuple.pl>
int main(void) {
    tuple<int, double, char> t = {1, 2.5, 'c'};
    return get<3>(t);
}

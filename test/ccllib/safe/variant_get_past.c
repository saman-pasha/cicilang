/* <variant.pl>: get<I> of an index past the end makes no function, and the reader refuses the typed call by the
   name of the function that the module has not, where C++ fails a static assertion (0.308) */
#include <variant.pl>
int main(void) {
    variant<int, double> v = 1;
    return (int)get<2>(v);
}

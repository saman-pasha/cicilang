/* A CALL BY NAME OF A FUNCTION WHOSE NAME ENDS IN A DIGIT, AND OF A VISIT (0.308): a call by name asks
   `<name><count>' first, and a count after a digit is a longer number -- a tuple's `get_1(t)' asked `_get_11',
   element 11's where the tuple has twelve, and a variant's `emplace_1(v, x)' `_emplace_12' --: a name that ends in a
   digit takes no count. A plain `visit_show(v)' is the visit's function by its own name, where the count's form
   `visit_show1' was the refusal of a family that the program does not declare. A plain call gives its function's own
   result, a pointer to the element, where the typed call `get<1>(t)' is the element's place. cicilang builds this file
   as C and cicilang++ as C++; both print digitnames.expect. It has no twin: C++ has no call by name */
#include <stdio.h>
#include <tuple.pl>
#include <variant.pl>
static int show_int(int x) { return 100 + x; }
static int show_double(double x) { return (int)(x * 10); }
int main(void) {
    tuple<int, int, int, int, int, int, int, int, int, int, int, int> t = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    printf("tuple: %d %d %d %d\n", *get_1(t), get<1>(t), *get_11(t), *get_0(t));
    *get_1(t) = 21;
    printf("place: %d %d\n", get<1>(t), get<11>(t));
    variant<int, int, int, int, int, int, int, int, int, int, int, int, double> v;
    emplace_1(v, 5);
    printf("variant: %zu %d\n", index(v), *get_1(v));
    printf("get_if: %d %d\n", get_if_1(&v) != 0, get_if_12(&v) != 0);
    emplace<12>(v, 2.5);
    printf("variant: %zu %g\n", index(v), get<12>(v));
    variant<int, double> w = 3;
    printf("visit: %d %d\n", visit_show(w), visit<show>(w));
    w = 1.5;
    printf("visit: %d %d\n", visit_show(w), visit<show>(w));
    return 0;
}

/* <variant.pl>: visit<f> of a family of which the program declares no function makes no function, and the reader
   refuses the call by the name of the function that the module does not make (0.308) */
#include <variant.pl>
static int show_int(int x) { return x; }
static int show_double(double x) { return (int)x; }
int main(void) {
    variant<int, double> v = 1;
    return visit<none>(v) + visit<show>(v);
}

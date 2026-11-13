/* <variant.pl>: visit<f>: the function of an alternative takes one parameter, the alternative or a pointer to it
   (0.308) */
#include <variant.pl>
static int show_int(int x, int y) { return x + y; }
static int show_double(double x) { return (int)x; }
int main(void) {
    variant<int, double> v = 1;
    return visit<show>(v);
}

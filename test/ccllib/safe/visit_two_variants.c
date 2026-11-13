/* <variant.pl>: visit<f> takes one variant, where C++'s takes any count (0.308) */
#include <variant.pl>
static int show_int(int x) { return x; }
static int show_double(double x) { return (int)x; }
int main(void) {
    variant<int, double> v = 1, w = 2.5;
    return visit<show>(v, w);
}

/* <variant.pl>: visit<f> takes a function's name between its < and >: an object's name is none (0.308) */
#include <variant.pl>
static int show_int(int x) { return x; }
static int show_double(double x) { return (int)x; }
int main(void) {
    variant<int, double> v = 1;
    int show = 2;
    return visit<show>(v) + show;
}

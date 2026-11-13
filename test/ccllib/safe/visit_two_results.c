/* <variant.pl>: visit<f> gives one type: the functions of the alternatives give one type, as C++'s visit asks
   (0.308) */
#include <variant.pl>
static int show_int(int x) { return x; }
static void show_double(double x) { (void)x; }
int main(void) {
    variant<int, double> v = 1;
    visit<show>(v);
    return 0;
}

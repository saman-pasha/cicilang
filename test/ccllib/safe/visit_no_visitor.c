/* <variant.pl>: visit<f> calls f_<word> for each alternative: one that the program does not declare is refused by
   its name (0.308) */
#include <variant.pl>
static int show_int(int x) { return x; }
int main(void) {
    variant<int, double> v = 1;
    return visit<show>(v);
}

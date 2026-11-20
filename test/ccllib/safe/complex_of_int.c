/* <complex.pl>: a complex's part is float, double or long double, as C++ specifies (1.6.4) */
#include <complex.pl>
int main(void) {
    complex<int> z = { 1, 2 };
    return (int)real(z);
}

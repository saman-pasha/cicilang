/* <functional.pl>: hash takes an integer, an enum or a pointer, and refuses a floating number by name (1.1.4) */
#include <functional.pl>
int main(void) {
    double d = 1.5;
    return (int)hash(d);
}

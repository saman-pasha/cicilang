/* <charconv.pl>: to_chars with a precision takes a floating number, as C++'s precision overloads do (1.6.4) */
#include <charconv.pl>
int main(void) {
    char b[8];
    to_chars_result r = to_chars(b, b + 8, 42, chars_fixed, 2);
    return (int)r.pos;
}

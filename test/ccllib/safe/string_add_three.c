/* <string.pl>: `a + b + c' adds c to the string that a + b makes, which has no name: the operator takes its operands'
   addresses (0.291) */
#include <string.pl>
int main(void) {
    string a = "a", b = "b", c = "c";
    string d = a + b + c;
    return (int)size(d);
}

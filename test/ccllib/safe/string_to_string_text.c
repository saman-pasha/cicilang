/* <string.pl>: to_string writes a number (0.291): a text is none */
#include <string.pl>
int main(void) {
    string s = to_string("abc");
    return (int)size(s);
}

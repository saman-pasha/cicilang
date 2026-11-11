/* <string.pl>: `==' compares a string with a string or with a text, as C++'s does: a character is neither (0.291) */
#include <string.pl>
int main(void) {
    string s = "c";
    return s == 'c';
}

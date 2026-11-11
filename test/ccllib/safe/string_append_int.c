/* <string.pl>: append takes a string, a text, a text and its count, a count and a character, or a part of a string:
   one number is none of them (0.291) */
#include <string.pl>
int main(void) {
    string s = "abc";
    append(s, 120);
    return (int)size(s);
}

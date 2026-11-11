/* <string.pl>: find takes a string, a text or a character, and a place: a floating value is none of them (0.291) */
#include <string.pl>
int main(void) {
    string s = "abc";
    return (int)find(s, 1.5);
}

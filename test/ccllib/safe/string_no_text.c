/* <string.pl>: a string is no text of C: c_str(s) gives its text (0.291) */
#include <stdio.h>
#include <string.pl>
int main(void) {
    string s = "abc";
    puts(s);
    return 0;
}

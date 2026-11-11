/* <string.pl>: `string t = s;' moves the string: its block is t's, and s is no string to read (0.291) */
#include <stdio.h>
#include <string.pl>
int main(void) {
    string s = "abc";
    string t = s;
    printf("%zu %zu\n", size(t), size(s));
    return 0;
}

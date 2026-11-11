/* <string.pl>: c_str(s) is a borrow of the string, and a change may replace its block (0.291; the safety rule of
   0.265) */
#include <stdio.h>
#include <string.pl>
int main(void) {
    string s = "abc";
    const char *p = c_str(s);
    append(s, "a text longer than fifteen characters");
    printf("%s\n", p);
    return 0;
}

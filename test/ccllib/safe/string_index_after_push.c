/* <string.pl>: &s[0] is a borrow of the string, and push_back may replace its block (0.291) */
#include <stdio.h>
#include <string.pl>
int main(void) {
    string s = "abc";
    char *p = &s[0];
    push_back(s, 'd');
    printf("%c\n", *p);
    return 0;
}

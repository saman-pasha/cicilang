/* <string_view.pl>: a view is a borrow of the string's characters, and a change may replace its block (0.295; the
   safety rule of 0.265) */
#include <stdio.h>
#include <string.pl>
#include <string_view.pl>
int main(void) {
    string s = "abc";
    string_view v = s;
    append(s, "a text longer than fifteen characters");
    printf("%zu\n", size(v));
    return 0;
}

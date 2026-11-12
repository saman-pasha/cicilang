/* <string_view.pl>: a view is a borrow of the string that it sees, which its block's end drops (0.295) */
#include <stdio.h>
#include <string.pl>
#include <string_view.pl>
int main(void) {
    string_view v;
    {
        string s = "a string of its block";
        v = s;
    }
    printf("%zu\n", size(v));
    return 0;
}

/* <charconv.pl>: to_chars of a bool is refused, as C++ deletes it (1.6.4); in C a bool is an object of type bool,
   _Bool, since C's `true' is the int 1 */
#include <stdbool.h>
#include <charconv.pl>
int main(void) {
    char b[8];
    bool flag = true;
    to_chars_result r = to_chars(b, b + 8, flag);
    return (int)r.pos;
}

/* <string_view.pl>: v[i] is a value, and a view writes no character (0.295) */
#include <string_view.pl>
int main(void) {
    char buf[8] = "abc";
    string_view v = buf;
    v[0] = 'x';
    return (int)size(v);
}

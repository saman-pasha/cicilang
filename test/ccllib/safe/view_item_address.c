/* <string_view.pl>: v[i] is a value, which has no address (0.295): data(v) + i is the place */
#include <string_view.pl>
int main(void) {
    string_view v = "abc";
    const char *p = &v[1];
    return *p;
}

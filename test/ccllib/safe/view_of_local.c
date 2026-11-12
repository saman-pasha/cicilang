/* <string_view.pl>: a view of a local array leaves its function (0.295) */
#include <string_view.pl>
static string_view name(void) {
    char buf[8] = "local";
    string_view v = buf;
    return v;
}
int main(void) {
    string_view n = name();
    return (int)size(n);
}

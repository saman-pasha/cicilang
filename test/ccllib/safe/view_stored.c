/* <string_view.pl>: a function puts a view of its own text in the caller's view (0.295): the caller's view would see
   the text of another source than its own */
#include <string_view.pl>
static void put(string_view *to, const char *text) {
    string_view w = text;
    *to = w;
}
int main(void) {
    string_view v = "abc";
    put(&v, "defg");
    return (int)size(v);
}

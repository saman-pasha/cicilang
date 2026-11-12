/* <string_view.pl>: a view of a parameter's view returned with no tie (0.295): the caller would not know what it sees */
#include <string_view.pl>
static string_view h(string_view w) { string_view r = w; return r; }
int main(void) { string_view v = "abc"; string_view x = h(v); return (int)size(x); }

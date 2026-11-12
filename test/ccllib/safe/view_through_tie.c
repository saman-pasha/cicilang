/* <string_view.pl>: the view that a function returns by its tie sees its argument's source, a string that its block
   drops (0.295) */
#include <string_view.pl>
#include <string.pl>
static string_view g(string_view w) tie w { string_view r = w; return r; }
int main(void) { string_view x; { string s = "abc"; string_view v = s; x = g(v); } return (int)size(x); }

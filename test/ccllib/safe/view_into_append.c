/* <string_view.pl>: a view of the string handed beside it to a change of the string (0.295; the rule of 0.293): the
   part goes by the string and its place, append(s, s, 1) */
#include <string.pl>
#include <string_view.pl>
int main(void) {
    string s = "abc";
    string_view v = s;
    append(s, v);
    return (int)size(s);
}

/* <string_view.pl>: a character is no text that a view is compared with (0.295): C++ has no such form */
#include <string_view.pl>
int main(void) {
    string_view v = "a";
    return v == 'a';
}

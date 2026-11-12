/* <string_view.pl>: a basic_string_view's element is char (0.295): the other character types wait */
#include <string_view.pl>
int main(void) {
    basic_string_view<int> w;
    return (int)size(w);
}

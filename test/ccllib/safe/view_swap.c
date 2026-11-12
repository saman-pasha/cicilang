/* <string_view.pl>: a view has no swap (0.295): a function that puts a view of one source in another's place is
   refused by the safe part */
#include <string_view.pl>
int main(void) {
    string_view a = "abc", b = "de";
    swap(a, b);
    return (int)size(a);
}

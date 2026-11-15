/* phase 1c: a mutating algorithm over a view is refused by name; a view is read-only */
#include <string_view.pl>
#include <algorithm.pl>
int main(void) {
    string_view v = "cba";
    sort(v);
    return 0;
}

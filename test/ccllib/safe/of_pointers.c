/* <vector.pl>: an element that is a pointer is refused where the type is written: a vector holds values (0.274) */
#include <stdio.h>
#include <vector.pl>
int main(void) {
    vector<const char *> names;
    printf("%zu\n", size(names));
    return 0;
}

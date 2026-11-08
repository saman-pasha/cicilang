/* LIST AND MAP LITERALS (0.263): the reader check k124 -- a constant that char cannot hold narrows */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(void) {
    vector<char> a = [char; 65, 300];
    return 0;
}

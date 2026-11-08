/* AUTODROP (0.262): a drop that leaves its object's owner live: the owner would leak at every scope's end */
#include <stdlib.h>
#include "dropnone.pl"
int main(void) {
    bag<int> b;
    bag_int_fill(&b);
    return 0;
}

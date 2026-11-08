/* LIST AND MAP LITERALS (0.263): the driver check -- a literal where no place gives it a type, a branch of a conditional,
   is refused by name */
#include <stdlib.h>
#include "run/tvector.pl"
#include "run/literal.pl"
int main(int argc, char **argv) {
    (void)argv;
    vector<int> a = argc > 1 ? [1] : [2];
    return (int)len(a);
}

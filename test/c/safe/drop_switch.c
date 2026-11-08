/* AUTODROP (0.262): a case label after an object's declaration in the switch's own block: the jump to it passes the
   declaration, and the drop at the block's end would run over an object never set (C++'s [stmt.dcl]/3) */
#include <stdio.h>
#include <stdlib.h>
#include "../run/tvector.pl"
int main(int argc, char **argv) {
    (void)argv;
    switch (argc) {
    case 1:
        vector<int> a;
        push(a, 1);
        printf("one\n");
    case 2:
        printf("two\n");
    }
    return 0;
}

/* A CONTINUE IN A SWITCH CLOSES THE LOOP'S BODY (0.290): an owner of the body that is live at the continue is leaked
   there, and the check says so -- until 0.290 it stopped at every continue in a switch, with no line named */
#include <stdlib.h>
int main(void) {
    int s = 0;
    for (int i = 0; i < 4; i++) {
        own int *p = malloc(sizeof(int));
        if (!p) return 1;
        *p = i;
        switch (i) {
        case 1: continue;
        }
        s += *p;
        free(p);
    }
    return s == 0;
}

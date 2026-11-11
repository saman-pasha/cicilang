/* A RECORD WITH AN OWN FIELD, READ OUT OF A TABLE, IS NOT A PLAIN SLOT'S VALUE (0.290): a record that holds plain
   pointers alone goes from one slot into another; one that holds an owner's pointer would leave two owners of one
   block */
#include <stdio.h>
struct rec { own char *data; const char *label; };
static struct rec table[2];
static struct rec kept;
int main(void) {
    table[0].label = "t";
    kept = table[0];
    puts(kept.label);
    return 0;
}

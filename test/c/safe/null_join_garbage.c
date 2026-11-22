/* null_join_garbage.c (1.6.18): a field whose owner is null on one path is the other path's at the join -- the other
   path's node came from malloc, its next never given anything: refused where next is freed */
#include <stdio.h>
#include <stdlib.h>
typedef struct node { int v; own struct node *next; } node;
int main(void) {
    own node *head = malloc(sizeof(node));
    if (head == NULL) puts("none");
    free(head->next);
    free(head);
    return 0;
}

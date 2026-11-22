/* null_join_garbage2.c (1.6.18): the same join, the null path second -- `head != NULL' leaves it null where the test
   fails; the other path's next was never given anything: refused where next is freed */
#include <stdio.h>
#include <stdlib.h>
typedef struct node { int v; own struct node *next; } node;
int main(void) {
    own node *head = malloc(sizeof(node));
    if (head != NULL) puts("some");
    free(head->next);
    free(head);
    return 0;
}

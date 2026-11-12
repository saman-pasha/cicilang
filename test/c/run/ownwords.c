/* THE WORD `own' WHERE IT IS THE OWNER'S (0.306): a specifier, `own int *p'; a pointer's qualifier, `int *own p'; an
   own pointer parameter with no name in a prototype, before another parameter; an own member, and an own array in a
   struct behind an own pointer -- read as they were, beside the refusals of test/c/own_*.c, where the word stands as a
   name. It prints what clang's build prints with `own' defined empty */
#include <stdio.h>
#include <stdlib.h>
typedef struct node { int v; own struct node *next; } node;
typedef struct tree { int n; own node *C[2]; } tree;
static int sum(node *own, int n);
static int sum(own node *p, int n) {
    if (!p) return n;
    own node *q = p->next;
    int v = p->v;
    free(p);
    return sum(q, n + v);
}
int main(void) {
    own node *a = malloc(sizeof(node));
    if (!a) return 1;
    a->v = 1;
    a->next = 0;
    node *own b = malloc(sizeof(node));
    if (!b) { free(a); return 1; }
    b->v = 2;
    b->next = a;
    printf("%d\n", sum(b, 0));
    own tree *t = calloc(1, sizeof(tree));
    if (!t) return 1;
    t->C[1] = malloc(sizeof(node));
    if (t->C[1]) { t->C[1]->v = 4; t->C[1]->next = 0; }
    printf("%d\n", t->C[1] ? t->C[1]->v : 0);
    free(t);
    return 0;
}

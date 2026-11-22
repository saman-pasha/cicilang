/* loopjoins.c (1.6.18): loops and joins that the safe part refused until 1.6.18, each right -- new memory given again
   where a null test found none, a free on the null path, a loop that tries again while its pointer is null, a list built
   by one loop and freed by another, a list of two nodes freed by a while, a plain and an own pointer freed by a while
   that tests them, the do-while(0) of a macro over an own and a plain pointer, a do-while whose body runs once, a
   do-while that tests what its body freed, a do-while that frees a list of two nodes, and an own pointer that is null on one path and holds a node, or a struct with
   an own member, on the other; each prints as clang's build with `own' defined empty, as C and as C++ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define SAFE_FREE(p) do { free(p); (p) = NULL; } while (0)
typedef struct node { int v; own struct node *next; } node;
static int lazy(void) {
    char *once = malloc(8);
    if (once == NULL) once = malloc(8);
    if (once == NULL) return -1;
    strcpy(once, "lazy");
    int n = (int)strlen(once);
    free(once);
    return n;
}
static int null_path(void) {
    char *p = malloc(4);
    if (!p) free(p);
    int ok = p != NULL;
    free(p);
    return ok;
}
static int retry(void) {
    char *p = malloc(4);
    int n = 0;
    while (!p) { p = malloc(4); n++; }
    free(p);
    return n;
}
static int list(int k) {
    own node *head = NULL;
    for (int i = 0; i < k; i++) {
        own node *n = malloc(sizeof(node));
        if (!n) break;
        n->v = i + 1;
        n->next = head;
        head = n;
    }
    int sum = 0;
    for (node *c = head; c; c = c->next) sum += c->v;
    while (head) { own node *next = head->next; free(head); head = next; }
    return sum;
}
static int two_nodes(void) {
    own node *a = malloc(sizeof(node));
    if (!a) return -1;
    a->v = 1;
    a->next = NULL;
    own node *b = malloc(sizeof(node));
    if (!b) { free(a); return -1; }
    b->v = 2;
    b->next = a;
    own node *head = b;
    int n = 0;
    while (head) { own node *next = head->next; n += head->v; free(head); head = next; }
    return n;
}
static int plain_while(void) {
    char *p = malloc(4);
    int n = 0;
    while (p) { free(p); p = NULL; n++; }
    return n;
}
static int own_while(void) {
    own char *p = malloc(4);
    int n = 0;
    while (p != NULL) { free(p); p = NULL; n++; }
    return n;
}
static int macro_free(void) {
    own char *a = malloc(4);
    char *b = malloc(4);
    SAFE_FREE(a);
    SAFE_FREE(b);
    return a == NULL && b == NULL;
}
static int do_once(void) {
    own char *p = malloc(4);
    do { free(p); } while (0);
    return 1;
}
static int do_test(void) {
    char *p = malloc(4);
    int n = 0;
    do { free(p); p = NULL; n++; } while (p);
    return n;
}
static int maybe_node(int k) {
    own node *head = NULL;
    if (k > 1) {
        own node *n = malloc(sizeof(node));
        if (!n) return -1;
        n->v = k;
        n->next = NULL;
        head = n;
    }
    int v = 0;
    if (head) { v = head->v; free(head->next); free(head); }
    return v;
}
static int do_walk(void) {
    own node *a = malloc(sizeof(node));
    if (!a) return -1;
    a->v = 3;
    a->next = NULL;
    own node *b = malloc(sizeof(node));
    if (!b) { free(a); return -1; }
    b->v = 4;
    b->next = a;
    own node *head = b;
    int n = 0;
    do { own node *next = head->next; n += head->v; free(head); head = next; } while (head);
    return n;
}
struct inner { own char *data; };
struct box { int n; struct inner in; };
static int maybe_box(int k) {
    own struct box *b = NULL;
    if (k > 1) {
        b = malloc(sizeof(struct box));
        if (!b) return -1;
        b->n = k;
        b->in.data = NULL;
    }
    int v = 0;
    if (b) { v = b->n; free(b->in.data); free(b); }
    return v;
}
int main(void) {
    printf("%d %d %d %d %d %d %d\n", lazy(), null_path(), retry(), list(4), two_nodes(), plain_while(), own_while());
    printf("%d %d %d %d %d %d %d %d\n", macro_free(), do_once(), do_test(), do_walk(), maybe_node(3), maybe_node(0),
           maybe_box(5), maybe_box(0));
    return 0;
}

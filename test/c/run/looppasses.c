/* looppasses.c (1.6.19): loops whose next pass finds what the last one left, each walked again from the join of its
   start and its end until the join is its start, and each right in every pass -- memory given once in the first pass
   and kept, a buffer freed and given again in each pass, a list of own nodes built at its head and freed node by node, a
   pointer that walks the list, two own pointers that pass memory on, which settles in the third pass, a loop in a loop,
   a continue that frees, a do-while that gives memory to a null pointer, a borrow moved along an array, a pointer
   stepped through a text, a goto over the rest of a pass's body, past a pointer of the body's own, a goto back in a
   pass's body, and two own pointers swapped in each pass of a for and of a do-while, whose states change places in each
   pass and settle in the second from the join; each prints as clang's build with `own' defined empty, as C and as
   C++ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct node { int v; own struct node *next; } node;
int main(void) {
    char *once = NULL;
    for (int i = 0; i < 3; i++) { if (once == NULL) once = malloc(8); if (once) once[i] = (char)('a' + i); }
    if (once) { once[3] = 0; printf("%s\n", once); }
    free(once);
    char *buf = malloc(4);
    for (int i = 0; i < 3 && buf; i++) { free(buf); buf = malloc(4 + i); }
    free(buf);
    own node *head = NULL;
    for (int i = 0; i < 4; i++) {
        own node *n = malloc(sizeof(node));
        if (!n) break;
        n->v = i;
        n->next = head;
        head = n;
    }
    int sum = 0;
    for (node *c = head; c; c = c->next) sum += c->v;
    while (head) { own node *next = head->next; free(head); head = next; }
    own char *a = NULL;
    own char *b = NULL;
    int given = 0;
    for (int i = 0; i < 4; i++) { free(b); b = a; a = malloc(4); if (a) given++; }
    free(a);
    free(b);
    int total = 0;
    for (int i = 0; i < 3; i++) {
        char *row = malloc(8);
        if (!row) break;
        for (int j = 0; j < 8; j++) row[j] = (char)(i + j);
        for (int j = 0; j < 8; j++) total += row[j];
        free(row);
    }
    int kept = 0, n = 0;
    while (n < 5) {
        n++;
        char *t = malloc(4);
        if (!t) continue;
        if (n % 2) { free(t); continue; }
        t[0] = 1;
        kept += t[0];
        free(t);
    }
    int arr[5] = {1, 2, 3, 4, 5};
    const int *at = arr;
    int prod = 1;
    while (at < arr + 5) { prod *= *at; at++; }
    char *late = NULL;
    int k = 0;
    do { if (!late) late = malloc(2); k++; } while (k < 3);
    free(late);
    const char *text = "a,b,,c";
    int commas = 0;
    for (const char *s = text; *s; s++) if (*s == ',') commas++;
    printf("%d %d %d %d %d %d %zu\n", sum, given, total, kept, prod, commas, strlen(text));
    char *q = NULL;
    int skipped = 0;
    for (int i = 0; i < 3; i++) {
        char *p = malloc(4);
        if (!p) break;
        if (i == 1) goto done;
        p[0] = 1;
        skipped += p[0];
    done:
        free(p);
        free(q);
        q = malloc(4);
    }
    free(q);
    char *r = NULL;
    int tries = 0;
    for (int i = 0; i < 3; i++) {
        int t = 0;
    again:
        t++;
        if (t < 2) goto again;
        tries += t;
        free(r);
        r = malloc(4);
    }
    free(r);
    own char *x = NULL;
    own char *y = malloc(4);
    for (int i = 0; i < 3; i++) { own char *t = x; x = y; y = t; }
    int held = (x != NULL) + (y != NULL);
    free(x);
    free(y);
    own char *u = malloc(2);
    own char *w = NULL;
    int m = 0;
    do { own char *t = u; u = w; w = t; m++; } while (m < 3);
    held += (u != NULL) + (w != NULL);
    free(u);
    free(w);
    printf("%d %d %d\n", skipped, tries, held);
    return 0;
}

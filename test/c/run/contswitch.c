/* A CONTINUE IN A SWITCH IN A LOOP (0.290; C17 6.8.6.2): the loop that it continues is the nearest loop, past the
   switch. The check closed its frames down to the switch alone, and every such `continue' stopped it with no line
   named. Here: a while, a for whose step still runs, a do-while whose condition is still asked, a switch in a
   switch, a continue from a block inside a case, a defer of the loop's body that the continue runs, and an owner
   that is freed before the continue. cicilang++ builds this file too */
#include <stdio.h>
#include <stdlib.h>
static int in_while(int n) {
    int s = 0;
    while (n > 0) {
        switch (n % 3) {
        case 0:
            if (n > 5) { s++; n--; continue; }
            s += 2; n--;
            continue;
        default:
            n--;
        }
        s += 10;
    }
    return s;
}
static int in_for(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        switch (i & 3) {
        case 1: continue;
        case 2: s += 100; break;
        default: s += 1;
        }
        s += 1000;
    }
    return s;
}
static int in_do(int n) {
    int s = 0, i = 0;
    do {
        i++;
        switch (i) {
        case 2: case 4: continue;
        }
        s += i;
    } while (i < n);
    return s;
}
static int nested(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        switch (i % 2) {
        case 0:
            switch (i % 4) {
            case 0: continue;
            default: s += 7;
            }
            break;
        default:
            s += 1;
        }
        s += 20;
    }
    return s;
}
static int with_defer(int n) {
    int s = 0, closed = 0;
    for (int i = 0; i < n; i++) {
        defer(closed) { closed++; }
        switch (i) {
        case 1: case 3: continue;
        }
        s += i;
    }
    return s * 100 + closed;
}
static int with_owner(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        own int *p = malloc(sizeof(int));
        if (!p) return -1;
        *p = i;
        switch (i % 3) {
        case 0:
            s += *p;
            free(p);
            continue;
        }
        s += 2 * *p;
        free(p);
    }
    return s;
}
int main(void) {
    printf("%d %d %d\n", in_while(9), in_while(4), in_while(0));
    printf("%d %d\n", in_for(8), in_for(3));
    printf("%d %d\n", in_do(6), in_do(1));
    printf("%d %d\n", nested(8), nested(1));
    printf("%d\n", with_defer(5));
    printf("%d\n", with_owner(7));
    return 0;
}

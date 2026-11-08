/* AUTODROP (0.262): the reader check k117 -- an int declared with the name of an autodropped object, in an inner block,
   hides it from the walk of the moves: use(a) passes the int, and take(a) after the block moves the object */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "run/autodrop.pl"
static int use(int v) { return v; }
static int take(track<int> t) { return t.val; }
int main(void) {
    track<int> a = tracked<int>("a", 1);
    { int a = 2; printf("%d\n", use(a)); }
    return take(a);
}

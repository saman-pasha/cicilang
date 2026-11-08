/* AUTODROP (0.262; CCLLIB.md's phase 0.5): each object of track<T> is dropped where its scope ends, on every way out
   of it -- the block's end, a return, a break, a continue, a goto -- the last declared first. An object named whole
   by value moves, and the move leaves it empty, so that its drop prints nothing; a parameter by value is the callee's;
   a for's object is dropped when the loop ends. Nothing is freed by hand. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "autodrop.pl"
static int early(int k) {
    track<int> a = tracked<int>("early.a", 1);
    if (k == 0) return 10;
    track<int> b = tracked<int>("early.b", 2);
    if (k == 1) return 20 + b.val;
    return 30 + a.val + b.val;
}
static track<int> pass(int n) { track<int> t = tracked<int>("pass.t", n); return t; }
static int take(track<int> t) { return t.val; }
int main(void) {
    printf("early %d\n", early(0));
    printf("early %d\n", early(1));
    printf("early %d\n", early(2));
    for (int i = 0; i < 4; i++) {
        track<int> c = tracked<int>("loop.c", i);
        if (i == 1) continue;
        if (i == 3) break;
        printf("body %d\n", c.val);
    }
    {
        track<int> d = tracked<int>("block.d", 5);
        track<int> e = tracked<int>("block.e", 6);
        printf("block %d\n", d.val + e.val);
    }
    {
        track<int> g = tracked<int>("goto.g", 7);
        if (g.val == 7) goto out;
        printf("not here\n");
    }
out:
    printf("out\n");
    track<int> m = pass(8);
    track<int> n = m;
    printf("moved %d\n", n.val);
    printf("take %d\n", take(tracked<int>("take.t", 9)));
    track<int> k = tracked<int>("main.k", 10);
    printf("take %d\n", take(k));
    for (track<int> f = tracked<int>("for.f", 11); f.val < 13; f.val++) printf("for %d\n", f.val);
    track<double> x = tracked<double>("main.x", 1.5);
    printf("end %.1f\n", x.val);
    return 0;
}

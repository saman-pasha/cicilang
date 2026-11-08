#include <stdio.h>
#include <stdlib.h>
#include "tvector.pl"
#include "unread.pl"
int main(void) {
    loop(m, 3, println("m = {}", m));
    loop(i, 2, loop(j, 2, println("{} {}", i, j)));
    vector<int> v = [int; 5, 3, 9, 1];
    each(v, x, println("x = {}", x * 10));
    int total = sum_by(v, x, x * x);
    println("total = {}", total);
    sort_by(v, a, b, a > b);
    each(v, x, print("{} ", x));
    println("");
    loop(k, 2, { y := k * 2.5; println("y = {}", y); });
    double m = 0.5;
    loop(m, 2, println("inner m = {}", m));
    println("outer m = {}", m);
    w := at(v, 0);
    println("w = {}", w);
    double k = 1.5;
    for (int k = 0; k < 1; k++) println("for k = {}", k);
    println("k = {}", k);
    return 0;
}

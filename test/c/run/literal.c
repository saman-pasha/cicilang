/* LIST AND MAP LITERALS (0.263; CCLLIB.md's phase 0.6): a literal takes the type that its place gives -- a declaration's
   type, the left side of `=', a call's parameter, a return's function -- or, at `:=', vector<T> or map<K, V> of the
   types it names or that its elements give by C's usual conversions. An empty literal is the empty object; a key given
   twice keeps its first value. */
#include <stdio.h>
#include <stdlib.h>
#include "tvector.pl"
#include "literal.pl"
static size_t count(vector<int> v) { return len(v); }
static vector<double> halves(void) { return [0.5, 1.5, 2.5]; }
int main(void) {
    v := [int; 5, 3, 9];
    vector<double> w = [1, 2.5];
    m := [int:double; 5: 1.25, 3: 2.5];
    vector<int> e = [];
    vector<int> e2 = [int;];
    int k = 1;
    map<int, int> d = [k: 10, 1: 20, 2: 30,];
    vector<long> x;
    x = [long; 7, 8];
    vector<float> f = [float; 1.5, 2.25];
    vector<char> c = [char; 'a', 66, 'c'];
    printf("%zu %d %d %d\n", len(v), at(v, 0), at(v, 1), at(v, 2));
    printf("%zu %.1f %.1f\n", len(w), at(w, 0), at(w, 1));
    printf("%zu %.2f %.2f\n", size(m), get(m, 5), get(m, 3));
    printf("%zu %zu %zu %d %d\n", len(e), len(e2), size(d), get(d, 1), get(d, 2));
    printf("%zu %ld %.2f %c%c%c\n", len(x), at(x, 1), at(f, 1), at(c, 0), at(c, 1), at(c, 2));
    printf("%zu\n", count([4, 5, 6, 7]));
    vector<double> h = halves();
    printf("%zu %.1f\n", len(h), at(h, 2));
    return 0;
}

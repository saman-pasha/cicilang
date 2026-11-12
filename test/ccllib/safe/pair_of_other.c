/* <pair.pl>: a pair is made by braces or of a pair of its own type: one of other member types is refused, where C++
   converts each member (0.301) */
#include <pair.pl>
int main(void) {
    pair<int, int> a = {1, 2};
    pair<int, double> b = a;
    return b.first == 1 ? 0 : 1;
}

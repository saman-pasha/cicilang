/* <pair.pl>: a pair's member is no array (0.301) */
#include <pair.pl>
typedef int two[2];
int main(void) {
    pair<two, int> p;
    return p.second;
}

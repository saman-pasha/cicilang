// AN ITERATOR OF A COMMA OVER A CONTAINER (1.6.13) borrows the container: `it = (g(), v).begin();' dangles when v's
// block ends, as `it = v.begin();' does
#include <cstdio>
#include <vector>
int g() { return 0; }
int main() { std::vector<int>::iterator it; { std::vector<int> v = {1}; it = (g(), v).begin(); } std::printf("%d\n", *it); return 0; }

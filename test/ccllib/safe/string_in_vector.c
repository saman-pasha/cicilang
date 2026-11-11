/* <string.pl>: a string holds an own pointer, and a vector's element is a value with no pointer in it (0.291) */
#include <string.pl>
#include <vector.pl>
int main(void) {
    vector<string> names;
    return (int)size(names);
}

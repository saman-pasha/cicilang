// the program's own headers read as its file is (0.268): a header's function that uses the header's own macro, and a
// header that reads only through the preprocessor, whose functions and object are the program's, each defined once
extern "C" int printf(const char *, ...);
#include "hdrmacro.h"
#include "hdrmacro2.h"
int main() {
    printf("%d %d %d %d %d\n", twice_h(21), thrice_h(5), plain_h(1), hcount, TWICE(4));
    return 0;
}

/* <stringstream.pl>: str(s) is a borrow of the stream's buffer (1.6.3), which the stream's drop frees: the program
   does not free it */
#include <stdio.h>
#include <stdlib.h>
#include <stringstream.pl>
int main(void) {
    stringstream<> s;
    s << 1;
    char *p = str(s);
    puts(p);
    free(p);
    return 0;
}

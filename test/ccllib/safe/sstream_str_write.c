/* <stringstream.pl>: str(s) is a borrow of the stream's buffer, tied to the stream (1.6.3), and a write to the stream
   may replace the buffer: the text that str gave is not read after the write */
#include <stdio.h>
#include <stringstream.pl>
int main(void) {
    stringstream<> s;
    s << 1;
    char *p = str(s);
    s << "a text that is longer than the first room of thirty-two bytes, so the buffer grows";
    puts(p);
    return 0;
}

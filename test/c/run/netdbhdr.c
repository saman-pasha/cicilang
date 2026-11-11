/* A HEADER WHOSE RAW READ THE LEXER CANNOT TAKE IS READ PREPROCESSED (0.290): glibc's <netdb.h> has a comment that
   begins on a `#define' line and ends on a later one, with an apostrophe between (`locale's'), and the raw lexer,
   which ends a directive at its line's end, met a character constant that never ends. The header was dropped whole
   with no message: `struct addrinfo' was incomplete and `getaddrinfo' undeclared */
#include <netdb.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_flags = AI_PASSIVE;
    hints.ai_socktype = 1;
    struct hostent *h = 0;
    int (*look)(const char *, const char *, const struct addrinfo *, struct addrinfo **) = getaddrinfo;
    printf("%d %d %d %d %d\n", hints.ai_flags == AI_PASSIVE, hints.ai_next == 0,
           (int)(sizeof hints >= 3 * sizeof(void *)), h == 0, look != 0);
    return 0;
}

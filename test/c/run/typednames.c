/* CALLS BY NAME TOLD BY AN ARGUMENT'S TYPE (0.288): text<char>'s append, insert and find each have several forms, as
   std::string's have, and the reader asks the function named with the word of an argument's type before the plain
   one: a text, a literal, an array of char, a pointer to const char, a character; a form with a count is told by the
   count, and one by the count and the word. A typedef of the instance asks the instance's names, and C's literal, a
   `char *', asks the name of the pointer to const: one function serves C's literal and C++'s. cicilang builds this file
   as C and cicilang++ as C++ */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tnames.pl"
typedef text<char> str;
int main(void) {
    text<char> a = "ab";
    str b = "cd";
    char buf[8] = "xyz";
    const char *q = "!";
    char c = 'y';
    append(a, b);
    append(a, "ef");
    append(a, buf);
    append(a, q);
    append(a, 2, '-');
    append(a, "ghijk", 2);
    printf("%s %zu\n", c_str(a), size(a));
    insert(a, 2, "<>");
    insert(a, 0, b);
    printf("%s\n", c_str(a));
    printf("%ld %ld %ld %ld %ld %ld\n", find(a, 'x'), find(a, c), find(a, b), find(a, "ef"), find(a, q), find(a, "no"));
    a += "+";
    a += b;
    b += buf;
    printf("%s %s %d %d %d %d\n", c_str(a), c_str(b), a == "x", b == "cdxyz", a == a, a == b);
    return 0;
}

/* A CALL'S ARGUMENT OF ANOTHER TYPE (0.288): splice takes a list where its third argument goes. A C text there was
   handed as it was written, with no message, and the function read the text's bytes as a list's */
#include <list.pl>
int main(void) {
    list<int> l = [1, 2];
    splice(l, 0, "abc");
    return 0;
}

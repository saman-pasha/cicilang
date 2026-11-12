/* <string.pl>: c_str(s) is a borrow of the string's block, and append(s, ...) may replace the block (0.293): a source
   in the string itself goes as a part of it, append(s, s, 1) */
#include <string.pl>
int main(void) {
    string s = "abc";
    append(s, c_str(s) + 1);
    return (int)size(s);
}

/* <string.pl>: C has no conversion of a text to a record, so a text is no string parameter's value (0.291; it went to
   LLVM's parser) */
#include <string.pl>
static size_t count(string who) { return size(who); }
int main(void) { return (int)count("bob"); }

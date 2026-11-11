/* OPERATORS WHOSE LEFT OPERAND IS NO INSTANCE (0.291): the reader check k163 -- tag<char> has no relation for an int,
   so `5 == t' is refused by the name of the function that would take it */
#include "run/tmirror.pl"
int main(void) {
    tag<char> t = "abc";
    return 5 == t;
}

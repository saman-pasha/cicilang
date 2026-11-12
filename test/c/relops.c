/* `<=' AND `>=' OVER AN INSTANCE ARE ITS TYPE MACRO'S OWN `_le' AND `_ge' (0.304): the function named with the word of
   the right operand's type first, the plain one after it, the operands in their order; with the instance on the right
   alone the other one's, `x <= o' as `o >= x'. The reader gate's k166 reads it; test/ccllib/relations.c runs them */
#include <vector.pl>
#include <optional.pl>
int main(void) {
    vector<double> a = [1, 2], b = [1, 3];
    optional<double> o = 2.5;
    int r = (a <= b) + (a >= b);
    r += (o <= 3.0) + (o >= 3.0) + (3.0 <= o) + (3.0 >= o);
    r += (o <= o) + (o >= o);
    r += (o <= nullopt) + (o >= nullopt) + (nullopt <= o) + (nullopt >= o);
    return r == 0;
}

/* the typed call by name takes its first argument's address, as a call by name does: a value that is no lvalue -- a
   call's result -- is named first, where C++'s get binds a temporary to its reference (0.305) */
#include <tuple.pl>
static tuple<int, int> make(void) { tuple<int, int> t = {1, 2}; return t; }
int main(void) {
    return get<0>(make());
}

/* <optional.pl>: the place that emplace gives back is a borrow of the optional, tied to it; it does not leave the
   function that holds the optional (0.300) */
#include <optional.pl>
static int *place(void) {
    optional<int> o;
    return emplace(o, 3);
}
int main(void) { return *place(); }

/* <memory.pl>: a borrow of a shared_ptr's block does not leave the function that holds the handle (1.1.3) */
#include <memory.pl>
static int *leave(void) {
    shared_ptr<int> p = make_shared<int>(1);
    return get(p);
}
int main(void) {
    int *b = leave();
    return *b;
}

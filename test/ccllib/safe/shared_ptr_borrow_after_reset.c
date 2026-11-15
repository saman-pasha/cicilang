/* <memory.pl>: get(p) is a borrow of the block, and reset may free it (1.1.3; the safety rule of 0.265) */
#include <memory.pl>
int main(void) {
    shared_ptr<int> p = make_shared<int>(1);
    int *b = get(p);
    reset(p);
    return *b;
}

/* <memory.pl>: make_shared_for_overwrite makes its object's zero bytes and takes no argument (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<int> p = make_shared_for_overwrite<int>(1);
    return 0;
}

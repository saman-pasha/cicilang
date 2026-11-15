/* <memory.pl>: make_shared takes a value of its object's type and no more (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<int> p = make_shared<int>(1, 2);
    return 0;
}

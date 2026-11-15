/* <memory.pl>: make_shared takes the one type of its object (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<int> p = make_shared<int, double>(1);
    return 0;
}

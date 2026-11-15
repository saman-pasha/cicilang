/* <memory.pl>: a shared_ptr takes one type, its object's; a deleter waits (1.1.3) */
#include <memory.pl>
int main(void) {
    shared_ptr<int, double> p;
    return 0;
}

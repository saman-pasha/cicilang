/* <memory.pl>: a unique_ptr takes one type, its object's (0.309) */
#include <memory.pl>
int main(void) {
    unique_ptr<> p;
    return 0;
}

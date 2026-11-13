/* <memory.pl>: a unique_ptr takes one type: a deleter, C++'s second type, waits (0.309) */
#include <memory.pl>
int main(void) {
    unique_ptr<int, int> p;
    return 0;
}

/* <memory.pl>: a weak_ptr takes one type, its object's (1.1.5) */
#include <memory.pl>
int main(void) {
    weak_ptr<int, double> w;
    return 0;
}

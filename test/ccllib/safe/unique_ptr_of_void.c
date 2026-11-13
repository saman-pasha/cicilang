/* <memory.pl>: a unique_ptr's object is no void (0.309) */
#include <memory.pl>
int main(void) {
    unique_ptr<void> p;
    return 0;
}
